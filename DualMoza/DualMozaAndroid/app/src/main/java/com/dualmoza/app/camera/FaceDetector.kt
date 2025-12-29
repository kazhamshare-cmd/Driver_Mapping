package com.dualmoza.app.camera

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.PointF
import android.graphics.RectF
import android.util.Log
import com.dualmoza.app.data.PrivacyFilterType
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.face.Face
import com.google.mlkit.vision.face.FaceDetection
import com.google.mlkit.vision.face.FaceDetectorOptions
import com.google.mlkit.vision.face.FaceLandmark

/**
 * Face Detector using ML Kit for detecting faces and eye landmarks.
 * Applies mosaic effect to eye regions or full face.
 */
class FaceDetector {

    companion object {
        private const val TAG = "FaceDetector"
        private const val DETECTION_INTERVAL_MS = 100L // Detect every 100ms to reduce flickering
    }

    enum class MosaicMode {
        EYES_ONLY,      // Only mosaic eyes
        FULL_FACE       // Mosaic entire face
    }

    // ML Kit face detector
    private val detector by lazy {
        val options = FaceDetectorOptions.Builder()
            .setPerformanceMode(FaceDetectorOptions.PERFORMANCE_MODE_FAST)
            .setLandmarkMode(FaceDetectorOptions.LANDMARK_MODE_ALL)
            .setMinFaceSize(0.15f)
            .build()
        FaceDetection.getClient(options)
    }

    // Privacy filter settings
    var mosaicEnabled: Boolean = true
    var privacyFilterType: PrivacyFilterType = PrivacyFilterType.MOSAIC
    var mosaicIntensity: Int = 15 // Block size (5-30) for mosaic, blur radius for blur
    var mosaicMode: MosaicMode = MosaicMode.EYES_ONLY
    var mosaicCoverage: Float = 0.5f // 0.0 = eyes only, 0.5 = standard, 1.0 = full face

    // Detection state
    private var lastDetectionTime = 0L
    private var isDetecting = false
    private var lastFaces: List<Face> = emptyList()
    private var lastFaceRects: List<RectF> = emptyList()

    /**
     * Process bitmap and apply mosaic to detected regions.
     * Uses throttling and caching to prevent flickering.
     */
    fun processFrame(bitmap: Bitmap, callback: (Bitmap) -> Unit) {
        if (!mosaicEnabled) {
            callback(bitmap)
            return
        }

        val currentTime = System.currentTimeMillis()

        // Apply cached privacy filter immediately for smooth display
        val resultBitmap = if (lastFaceRects.isNotEmpty()) {
            applyPrivacyFilterToRects(bitmap, lastFaceRects)
        } else {
            bitmap
        }

        // Run detection at intervals to prevent overload
        if (!isDetecting && (currentTime - lastDetectionTime) >= DETECTION_INTERVAL_MS) {
            isDetecting = true
            lastDetectionTime = currentTime

            val inputImage = InputImage.fromBitmap(bitmap, 0)

            detector.process(inputImage)
                .addOnSuccessListener { faces ->
                    lastFaces = faces
                    lastFaceRects = calculateMosaicRects(bitmap, faces)
                    isDetecting = false
                }
                .addOnFailureListener { e ->
                    Log.e(TAG, "Face detection failed", e)
                    isDetecting = false
                }
        }

        callback(resultBitmap)
    }

    private fun calculateMosaicRects(bitmap: Bitmap, faces: List<Face>): List<RectF> {
        val rects = mutableListOf<RectF>()

        for (face in faces) {
            val faceRect = RectF(face.boundingBox)
            val leftEye = face.getLandmark(FaceLandmark.LEFT_EYE)
            val rightEye = face.getLandmark(FaceLandmark.RIGHT_EYE)

            // iOSと同様のモザイク範囲計算
            // coverage 0.0: 目の周辺のみ (幅70%, 高さ30%)
            // coverage 1.0: 頭全体+顎下 (幅170%, 高さ250%)

            // 目の中心位置を計算
            val eyesCenterY = if (leftEye != null && rightEye != null) {
                (leftEye.position.y + rightEye.position.y) / 2f
            } else {
                // ランドマークがない場合、顔の上部30%あたりを目の位置と推定
                faceRect.top + faceRect.height() * 0.30f
            }

            // coverage 1.0 では頭全体（髪の毛含む）+ 顎下をカバー
            val faceCenterY = faceRect.centerY()
            val headCenterY = faceCenterY + faceRect.height() * 0.15f
            val filterCenterY = eyesCenterY + (headCenterY - eyesCenterY) * mosaicCoverage
            val filterCenterX = faceRect.centerX()

            // coverage 0.0: 目の周辺のみ (幅70%, 高さ30%)
            // coverage 1.0: 頭全体+顎下 (幅170%, 高さ250%)
            val filterWidth = faceRect.width() * (0.7f + mosaicCoverage * 1.0f)
            val filterHeight = faceRect.height() * (0.3f + mosaicCoverage * 2.2f)

            // フィルター領域を計算
            val filterRect = RectF(
                (filterCenterX - filterWidth / 2f).coerceAtLeast(0f),
                (filterCenterY - filterHeight / 2f).coerceAtLeast(0f),
                (filterCenterX + filterWidth / 2f).coerceAtMost(bitmap.width.toFloat()),
                (filterCenterY + filterHeight / 2f).coerceAtMost(bitmap.height.toFloat())
            )
            rects.add(filterRect)
        }

        return rects
    }

    private fun getEyeRect(center: PointF, width: Int, height: Int, bitmap: Bitmap): RectF {
        return RectF(
            (center.x - width / 2f).coerceAtLeast(0f),
            (center.y - height / 2f).coerceAtLeast(0f),
            (center.x + width / 2f).coerceAtMost(bitmap.width.toFloat()),
            (center.y + height / 2f).coerceAtMost(bitmap.height.toFloat())
        )
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

        // Sample every other pixel for performance
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

    /**
     * Apply blur effect to a region using box blur algorithm.
     * The blur radius is controlled by mosaicIntensity (mapped to appropriate range).
     */
    private fun applyBlurToRegion(bitmap: Bitmap, canvas: Canvas, paint: Paint, region: RectF) {
        val left = region.left.toInt().coerceIn(0, bitmap.width - 1)
        val top = region.top.toInt().coerceIn(0, bitmap.height - 1)
        val right = region.right.toInt().coerceIn(1, bitmap.width)
        val bottom = region.bottom.toInt().coerceIn(1, bitmap.height)

        if (right <= left || bottom <= top) return

        val width = right - left
        val height = bottom - top

        // Map mosaicIntensity (5-100) to blur radius (2-25)
        val blurRadius = (mosaicIntensity * 0.25f).toInt().coerceIn(2, 25)

        // Extract the region to blur
        val regionBitmap = Bitmap.createBitmap(bitmap, left, top, width, height)
        val blurredRegion = applyBoxBlur(regionBitmap, blurRadius)
        regionBitmap.recycle()

        // Draw the blurred region back
        canvas.drawBitmap(blurredRegion, left.toFloat(), top.toFloat(), paint)
        blurredRegion.recycle()
    }

    /**
     * Simple box blur implementation.
     * Uses horizontal and vertical passes for efficiency.
     */
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
        lastFaces = emptyList()
        lastFaceRects = emptyList()
    }

    fun close() {
        detector.close()
    }
}
