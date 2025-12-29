package com.dualmoza.app.camera

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.util.Log
import com.dualmoza.app.data.PrivacyFilterType
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.objects.DetectedObject
import com.google.mlkit.vision.objects.ObjectDetection
import com.google.mlkit.vision.objects.defaults.ObjectDetectorOptions

/**
 * Person Detector using ML Kit Object Detection for detecting people.
 * Detects full body/upper body and applies privacy filter to head region.
 * Useful for detecting people from side profiles or back views.
 */
class PersonDetector {

    companion object {
        private const val TAG = "PersonDetector"
        private const val DETECTION_INTERVAL_MS = 150L // Slightly longer interval than face detection
        private const val PERSON_LABEL = "Person"
        private const val PERSON_CATEGORY = 0 // ML Kit uses category 0 for person
    }

    // ML Kit object detector
    private val detector by lazy {
        val options = ObjectDetectorOptions.Builder()
            .setDetectorMode(ObjectDetectorOptions.STREAM_MODE)
            .enableMultipleObjects()
            .enableClassification()
            .build()
        ObjectDetection.getClient(options)
    }

    // Privacy filter settings
    var mosaicEnabled: Boolean = true
    var privacyFilterType: PrivacyFilterType = PrivacyFilterType.MOSAIC
    var mosaicIntensity: Int = 15

    // Detection state
    private var lastDetectionTime = 0L
    private var isDetecting = false
    private var lastPersonRects: List<RectF> = emptyList()

    /**
     * Process bitmap and apply mosaic to detected person head regions.
     */
    fun processFrame(bitmap: Bitmap, callback: (Bitmap) -> Unit) {
        if (!mosaicEnabled) {
            callback(bitmap)
            return
        }

        val currentTime = System.currentTimeMillis()

        // Apply cached privacy filter immediately for smooth display
        val resultBitmap = if (lastPersonRects.isNotEmpty()) {
            applyPrivacyFilterToRects(bitmap, lastPersonRects)
        } else {
            bitmap
        }

        // Run detection at intervals
        if (!isDetecting && (currentTime - lastDetectionTime) >= DETECTION_INTERVAL_MS) {
            isDetecting = true
            lastDetectionTime = currentTime

            val inputImage = InputImage.fromBitmap(bitmap, 0)

            detector.process(inputImage)
                .addOnSuccessListener { objects ->
                    lastPersonRects = calculateHeadRects(bitmap, objects)
                    isDetecting = false
                }
                .addOnFailureListener { e ->
                    Log.e(TAG, "Person detection failed", e)
                    isDetecting = false
                }
        }

        callback(resultBitmap)
    }

    /**
     * Calculate head regions from detected objects.
     * Takes the upper portion of each detected person bounding box.
     */
    private fun calculateHeadRects(bitmap: Bitmap, objects: List<DetectedObject>): List<RectF> {
        val rects = mutableListOf<RectF>()

        for (obj in objects) {
            // Filter for person objects
            val isPerson = obj.labels.any { label ->
                label.text.equals(PERSON_LABEL, ignoreCase = true) ||
                label.index == PERSON_CATEGORY
            }

            // If no labels, still process as it might be a person
            if (!isPerson && obj.labels.isNotEmpty()) continue

            val boundingBox = RectF(obj.boundingBox)

            // Calculate head region (upper 40% of the bounding box)
            val headHeight = boundingBox.height() * 0.4f
            val headRect = RectF(
                boundingBox.left.coerceAtLeast(0f),
                boundingBox.top.coerceAtLeast(0f),
                boundingBox.right.coerceAtMost(bitmap.width.toFloat()),
                (boundingBox.top + headHeight).coerceAtMost(bitmap.height.toFloat())
            )

            // Only add if the rect is valid size
            if (headRect.width() > 20 && headRect.height() > 20) {
                rects.add(headRect)
            }
        }

        return rects
    }

    private fun applyPrivacyFilterToRects(bitmap: Bitmap, rects: List<RectF>): Bitmap {
        if (rects.isEmpty()) return bitmap

        val mutableBitmap = bitmap.copy(Bitmap.Config.ARGB_8888, true)
        val canvas = Canvas(mutableBitmap)
        val paint = Paint()

        for (rect in rects) {
            when (privacyFilterType) {
                PrivacyFilterType.MOSAIC -> applyMosaicToRegion(mutableBitmap, canvas, paint, rect)
                PrivacyFilterType.BLUR -> applyBlurToRegion(mutableBitmap, canvas, paint, rect)
            }
        }

        return mutableBitmap
    }

    private fun applyMosaicToRegion(bitmap: Bitmap, canvas: Canvas, paint: Paint, region: RectF) {
        val left = region.left.toInt().coerceIn(0, bitmap.width - 1)
        val top = region.top.toInt().coerceIn(0, bitmap.height - 1)
        val right = region.right.toInt().coerceIn(1, bitmap.width)
        val bottom = region.bottom.toInt().coerceIn(1, bitmap.height)

        if (right <= left || bottom <= top) return

        val blockSize = mosaicIntensity.coerceIn(5, 30)

        var y = top
        while (y < bottom) {
            var x = left
            while (x < right) {
                val blockRight = (x + blockSize).coerceAtMost(right)
                val blockBottom = (y + blockSize).coerceAtMost(bottom)

                val avgColor = getAverageColor(bitmap, x, y, blockRight, blockBottom)
                paint.color = avgColor
                canvas.drawRect(x.toFloat(), y.toFloat(), blockRight.toFloat(), blockBottom.toFloat(), paint)

                x += blockSize
            }
            y += blockSize
        }
    }

    private fun getAverageColor(bitmap: Bitmap, left: Int, top: Int, right: Int, bottom: Int): Int {
        var red = 0L
        var green = 0L
        var blue = 0L
        var count = 0

        var y = top
        while (y < bottom) {
            var x = left
            while (x < right) {
                val pixel = bitmap.getPixel(x, y)
                red += (pixel shr 16) and 0xFF
                green += (pixel shr 8) and 0xFF
                blue += pixel and 0xFF
                count++
                x += 2
            }
            y += 2
        }

        if (count == 0) return 0xFF808080.toInt()

        return (0xFF shl 24) or
                ((red / count).toInt() shl 16) or
                ((green / count).toInt() shl 8) or
                (blue / count).toInt()
    }

    private fun applyBlurToRegion(bitmap: Bitmap, canvas: Canvas, paint: Paint, region: RectF) {
        val left = region.left.toInt().coerceIn(0, bitmap.width - 1)
        val top = region.top.toInt().coerceIn(0, bitmap.height - 1)
        val right = region.right.toInt().coerceIn(1, bitmap.width)
        val bottom = region.bottom.toInt().coerceIn(1, bitmap.height)

        if (right <= left || bottom <= top) return

        val width = right - left
        val height = bottom - top

        val blurRadius = (mosaicIntensity * 0.25f).toInt().coerceIn(2, 25)

        val regionBitmap = Bitmap.createBitmap(bitmap, left, top, width, height)
        val blurredRegion = applyBoxBlur(regionBitmap, blurRadius)
        regionBitmap.recycle()

        canvas.drawBitmap(blurredRegion, left.toFloat(), top.toFloat(), paint)
        blurredRegion.recycle()
    }

    private fun applyBoxBlur(src: Bitmap, radius: Int): Bitmap {
        val width = src.width
        val height = src.height

        if (width <= 0 || height <= 0) return src

        val pixels = IntArray(width * height)
        src.getPixels(pixels, 0, width, 0, 0, width, height)

        val result = IntArray(width * height)

        // Horizontal pass
        for (y in 0 until height) {
            for (x in 0 until width) {
                var r = 0
                var g = 0
                var b = 0
                var count = 0

                for (dx in -radius..radius) {
                    val nx = (x + dx).coerceIn(0, width - 1)
                    val pixel = pixels[y * width + nx]
                    r += (pixel shr 16) and 0xFF
                    g += (pixel shr 8) and 0xFF
                    b += pixel and 0xFF
                    count++
                }

                result[y * width + x] = (0xFF shl 24) or
                        ((r / count) shl 16) or
                        ((g / count) shl 8) or
                        (b / count)
            }
        }

        // Vertical pass
        val finalResult = IntArray(width * height)
        for (y in 0 until height) {
            for (x in 0 until width) {
                var r = 0
                var g = 0
                var b = 0
                var count = 0

                for (dy in -radius..radius) {
                    val ny = (y + dy).coerceIn(0, height - 1)
                    val pixel = result[ny * width + x]
                    r += (pixel shr 16) and 0xFF
                    g += (pixel shr 8) and 0xFF
                    b += pixel and 0xFF
                    count++
                }

                finalResult[y * width + x] = (0xFF shl 24) or
                        ((r / count) shl 16) or
                        ((g / count) shl 8) or
                        (b / count)
            }
        }

        val blurred = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        blurred.setPixels(finalResult, 0, width, 0, 0, width, height)
        return blurred
    }

    fun clearCache() {
        lastPersonRects = emptyList()
    }

    fun close() {
        detector.close()
    }
}
