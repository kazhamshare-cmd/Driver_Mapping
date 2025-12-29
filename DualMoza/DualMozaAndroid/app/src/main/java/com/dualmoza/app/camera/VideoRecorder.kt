package com.dualmoza.app.camera

import android.Manifest
import android.content.ContentValues
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.media.MediaMuxer
import android.media.MediaRecorder
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.provider.MediaStore
import android.util.Log
import androidx.core.content.ContextCompat
import java.io.File
import java.nio.ByteBuffer
import java.text.SimpleDateFormat
import java.util.*
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger

/**
 * Video Recorder for encoding processed frames to H.264 video with AAC audio.
 * Accepts Bitmap frames and encodes them with optional watermark.
 */
class VideoRecorder(
    private val context: Context,
    private val isPro: Boolean
) {
    companion object {
        private const val TAG = "VideoRecorder"
        private const val VIDEO_WIDTH = 720
        private const val VIDEO_HEIGHT = 1280
        private const val VIDEO_BITRATE = 2_000_000 // 2 Mbps
        private const val VIDEO_FRAME_RATE = 30
        private const val VIDEO_I_FRAME_INTERVAL = 1
        private const val TIMEOUT_US = 10000L

        // Audio settings
        private const val AUDIO_SAMPLE_RATE = 44100
        private const val AUDIO_CHANNEL_CONFIG = AudioFormat.CHANNEL_IN_MONO
        private const val AUDIO_FORMAT = AudioFormat.ENCODING_PCM_16BIT
        private const val AUDIO_BITRATE = 128000 // 128 kbps
    }

    private var videoEncoder: MediaCodec? = null
    private var audioEncoder: MediaCodec? = null
    private var muxer: MediaMuxer? = null
    private var videoTrackIndex = -1
    private var audioTrackIndex = -1
    private var muxerStarted = false
    private var isRecording = AtomicBoolean(false)
    private var outputFile: File? = null

    // Track count for muxer synchronization
    private val tracksAdded = AtomicInteger(0)
    private val totalTracks = AtomicInteger(1) // Default to video only

    // Background threads
    private var videoEncoderThread: HandlerThread? = null
    private var videoEncoderHandler: Handler? = null
    private var audioThread: Thread? = null

    // Audio recording
    private var audioRecord: AudioRecord? = null

    // Presentation time tracking
    private var startTimeNs = 0L
    private var frameCount = 0L

    // Synchronization lock for muxer
    private val muxerLock = Object()

    // Watermark paint
    private val watermarkPaint = Paint().apply {
        color = android.graphics.Color.argb(180, 255, 255, 255)
        textSize = 36f
        isAntiAlias = true
        setShadowLayer(2f, 1f, 1f, android.graphics.Color.BLACK)
    }

    fun start() {
        if (isRecording.get()) return

        try {
            // Check if we have audio permission
            val hasAudioPermission = ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.RECORD_AUDIO
            ) == PackageManager.PERMISSION_GRANTED

            totalTracks.set(if (hasAudioPermission) 2 else 1)
            tracksAdded.set(0)

            // Start video encoder thread
            videoEncoderThread = HandlerThread("VideoEncoder").also { it.start() }
            videoEncoderHandler = Handler(videoEncoderThread!!.looper)

            // Create output file
            val dateFormat = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault())
            val fileName = "DualMoza_${dateFormat.format(Date())}.mp4"
            outputFile = File(context.cacheDir, fileName)

            // Create muxer first
            muxer = MediaMuxer(outputFile!!.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)

            // Configure video encoder
            val videoFormat = MediaFormat.createVideoFormat(
                MediaFormat.MIMETYPE_VIDEO_AVC,
                VIDEO_WIDTH,
                VIDEO_HEIGHT
            ).apply {
                setInteger(MediaFormat.KEY_BIT_RATE, VIDEO_BITRATE)
                setInteger(MediaFormat.KEY_FRAME_RATE, VIDEO_FRAME_RATE)
                setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, VIDEO_I_FRAME_INTERVAL)
                setInteger(
                    MediaFormat.KEY_COLOR_FORMAT,
                    MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420SemiPlanar
                )
            }

            videoEncoder = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC).apply {
                configure(videoFormat, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
                start()
            }

            // Configure audio encoder if permission granted
            if (hasAudioPermission) {
                setupAudioRecording()
            }

            startTimeNs = System.nanoTime()
            frameCount = 0
            isRecording.set(true)

            // Start audio recording thread
            if (hasAudioPermission && audioRecord != null) {
                startAudioRecording()
            }

            Log.d(TAG, "Video recording started: ${outputFile?.absolutePath}, hasAudio=$hasAudioPermission")

        } catch (e: Exception) {
            Log.e(TAG, "Error starting video recording", e)
            cleanup()
        }
    }

    private fun setupAudioRecording() {
        try {
            val bufferSize = AudioRecord.getMinBufferSize(
                AUDIO_SAMPLE_RATE,
                AUDIO_CHANNEL_CONFIG,
                AUDIO_FORMAT
            )

            audioRecord = AudioRecord(
                MediaRecorder.AudioSource.MIC,
                AUDIO_SAMPLE_RATE,
                AUDIO_CHANNEL_CONFIG,
                AUDIO_FORMAT,
                bufferSize * 2
            )

            // Configure audio encoder
            val audioFormat = MediaFormat.createAudioFormat(
                MediaFormat.MIMETYPE_AUDIO_AAC,
                AUDIO_SAMPLE_RATE,
                1 // Mono
            ).apply {
                setInteger(MediaFormat.KEY_BIT_RATE, AUDIO_BITRATE)
                setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
                setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, bufferSize * 2)
            }

            audioEncoder = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_AUDIO_AAC).apply {
                configure(audioFormat, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
                start()
            }

            Log.d(TAG, "Audio recording setup complete, bufferSize=$bufferSize")

        } catch (e: Exception) {
            Log.e(TAG, "Error setting up audio recording", e)
            audioRecord?.release()
            audioRecord = null
            audioEncoder?.release()
            audioEncoder = null
            totalTracks.set(1) // Fall back to video only
        }
    }

    private fun startAudioRecording() {
        audioThread = Thread {
            android.os.Process.setThreadPriority(android.os.Process.THREAD_PRIORITY_AUDIO)

            val bufferSize = AudioRecord.getMinBufferSize(
                AUDIO_SAMPLE_RATE,
                AUDIO_CHANNEL_CONFIG,
                AUDIO_FORMAT
            )
            val buffer = ByteArray(bufferSize)

            try {
                audioRecord?.startRecording()
                Log.d(TAG, "Audio recording started")

                while (isRecording.get()) {
                    val readSize = audioRecord?.read(buffer, 0, bufferSize) ?: 0
                    if (readSize > 0) {
                        encodeAudio(buffer, readSize)
                    }
                }

            } catch (e: Exception) {
                Log.e(TAG, "Error in audio recording thread", e)
            } finally {
                try {
                    audioRecord?.stop()
                } catch (e: Exception) {
                    Log.e(TAG, "Error stopping audio record", e)
                }
            }
        }.also { it.start() }
    }

    private fun encodeAudio(data: ByteArray, size: Int) {
        val encoder = audioEncoder ?: return

        try {
            val inputBufferIndex = encoder.dequeueInputBuffer(TIMEOUT_US)
            if (inputBufferIndex >= 0) {
                val inputBuffer = encoder.getInputBuffer(inputBufferIndex)
                inputBuffer?.clear()
                inputBuffer?.put(data, 0, size)

                val presentationTimeUs = (System.nanoTime() - startTimeNs) / 1000

                encoder.queueInputBuffer(
                    inputBufferIndex,
                    0,
                    size,
                    presentationTimeUs,
                    0
                )
            }

            drainAudioEncoder(false)

        } catch (e: Exception) {
            Log.e(TAG, "Error encoding audio", e)
        }
    }

    private fun drainAudioEncoder(endOfStream: Boolean) {
        val encoder = audioEncoder ?: return

        if (endOfStream) {
            val inputBufferIndex = encoder.dequeueInputBuffer(TIMEOUT_US)
            if (inputBufferIndex >= 0) {
                encoder.queueInputBuffer(
                    inputBufferIndex,
                    0,
                    0,
                    (System.nanoTime() - startTimeNs) / 1000,
                    MediaCodec.BUFFER_FLAG_END_OF_STREAM
                )
            }
        }

        val bufferInfo = MediaCodec.BufferInfo()

        while (true) {
            val outputBufferIndex = encoder.dequeueOutputBuffer(bufferInfo, TIMEOUT_US)

            when {
                outputBufferIndex == MediaCodec.INFO_TRY_AGAIN_LATER -> {
                    if (!endOfStream) break
                }
                outputBufferIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                    synchronized(muxerLock) {
                        val newFormat = encoder.outputFormat
                        audioTrackIndex = muxer?.addTrack(newFormat) ?: -1
                        Log.d(TAG, "Audio track added: $audioTrackIndex")
                        checkAndStartMuxer()
                    }
                }
                outputBufferIndex >= 0 -> {
                    val outputBuffer = encoder.getOutputBuffer(outputBufferIndex)

                    synchronized(muxerLock) {
                        if (outputBuffer != null && muxerStarted && audioTrackIndex >= 0) {
                            if ((bufferInfo.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG) != 0) {
                                bufferInfo.size = 0
                            }

                            if (bufferInfo.size > 0) {
                                outputBuffer.position(bufferInfo.offset)
                                outputBuffer.limit(bufferInfo.offset + bufferInfo.size)
                                muxer?.writeSampleData(audioTrackIndex, outputBuffer, bufferInfo)
                            }
                        }
                    }

                    encoder.releaseOutputBuffer(outputBufferIndex, false)

                    if ((bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
                        break
                    }
                }
            }
        }
    }

    /**
     * Add a frame to the video.
     * Call this with processed Bitmap frames at ~30fps.
     */
    fun addFrame(bitmap: Bitmap) {
        if (!isRecording.get()) return

        videoEncoderHandler?.post {
            try {
                encodeFrame(bitmap)
            } catch (e: Exception) {
                Log.e(TAG, "Error encoding frame", e)
            }
        }
    }

    private fun encodeFrame(originalBitmap: Bitmap) {
        val encoder = this.videoEncoder ?: return

        // Scale bitmap to video dimensions while preserving aspect ratio (center crop)
        val scaledBitmap = scaleAndCropToFill(originalBitmap, VIDEO_WIDTH, VIDEO_HEIGHT)
        val outputBitmap = if (isPro) scaledBitmap else addWatermark(scaledBitmap)

        // Convert bitmap to YUV420
        val yuvData = bitmapToYuv420(outputBitmap)

        // Get input buffer
        val inputBufferIndex = encoder.dequeueInputBuffer(TIMEOUT_US)
        if (inputBufferIndex >= 0) {
            val inputBuffer = encoder.getInputBuffer(inputBufferIndex)
            inputBuffer?.clear()
            inputBuffer?.put(yuvData)

            // Calculate presentation time
            val presentationTimeUs = (System.nanoTime() - startTimeNs) / 1000

            encoder.queueInputBuffer(
                inputBufferIndex,
                0,
                yuvData.size,
                presentationTimeUs,
                0
            )
            frameCount++
        }

        // Drain output buffers
        drainVideoEncoder(false)

        // Cleanup scaled bitmap if it's different from input
        if (scaledBitmap != originalBitmap) {
            scaledBitmap.recycle()
        }
        if (outputBitmap != scaledBitmap) {
            outputBitmap.recycle()
        }
    }

    private fun addWatermark(bitmap: Bitmap): Bitmap {
        val output = bitmap.copy(Bitmap.Config.ARGB_8888, true)
        val canvas = Canvas(output)

        val text = "DualMoza"
        val textWidth = watermarkPaint.measureText(text)
        canvas.drawText(
            text,
            bitmap.width - textWidth - 20f,
            bitmap.height - 30f,
            watermarkPaint
        )

        return output
    }

    /**
     * Scale and crop bitmap to fill target dimensions while preserving aspect ratio.
     * Centers the crop area.
     */
    private fun scaleAndCropToFill(source: Bitmap, targetWidth: Int, targetHeight: Int): Bitmap {
        val srcWidth = source.width
        val srcHeight = source.height
        val srcAspect = srcWidth.toFloat() / srcHeight
        val targetAspect = targetWidth.toFloat() / targetHeight

        val scaledWidth: Int
        val scaledHeight: Int

        if (srcAspect > targetAspect) {
            // Source is wider - scale to match height, crop width
            scaledHeight = targetHeight
            scaledWidth = (targetHeight * srcAspect).toInt()
        } else {
            // Source is taller - scale to match width, crop height
            scaledWidth = targetWidth
            scaledHeight = (targetWidth / srcAspect).toInt()
        }

        // Scale the bitmap
        val scaledBitmap = Bitmap.createScaledBitmap(source, scaledWidth, scaledHeight, true)

        // Calculate crop offsets to center
        val cropX = (scaledWidth - targetWidth) / 2
        val cropY = (scaledHeight - targetHeight) / 2

        // Crop to target size
        val result = Bitmap.createBitmap(scaledBitmap, cropX, cropY, targetWidth, targetHeight)

        // Clean up scaled bitmap if it's different from result
        if (scaledBitmap != result) {
            scaledBitmap.recycle()
        }

        return result
    }

    private fun bitmapToYuv420(bitmap: Bitmap): ByteArray {
        val width = bitmap.width
        val height = bitmap.height

        val argb = IntArray(width * height)
        bitmap.getPixels(argb, 0, width, 0, 0, width, height)

        val yuvSize = width * height * 3 / 2
        val yuv = ByteArray(yuvSize)

        // Convert ARGB to YUV420 (NV12 format: Y plane followed by interleaved UV)
        var yIndex = 0
        val uvStart = width * height

        for (j in 0 until height) {
            for (i in 0 until width) {
                val pixel = argb[j * width + i]
                val r = (pixel shr 16) and 0xFF
                val g = (pixel shr 8) and 0xFF
                val b = pixel and 0xFF

                // Y component (BT.601 standard)
                val y = ((66 * r + 129 * g + 25 * b + 128) shr 8) + 16
                yuv[yIndex++] = y.coerceIn(0, 255).toByte()

                // U and V components (subsampled 2x2, NV12 interleaved UV)
                if (j % 2 == 0 && i % 2 == 0) {
                    val uvIndex = uvStart + (j / 2) * width + i
                    val u = ((-38 * r - 74 * g + 112 * b + 128) shr 8) + 128
                    val v = ((112 * r - 94 * g - 18 * b + 128) shr 8) + 128
                    yuv[uvIndex] = u.coerceIn(0, 255).toByte()
                    yuv[uvIndex + 1] = v.coerceIn(0, 255).toByte()
                }
            }
        }

        return yuv
    }

    private fun checkAndStartMuxer() {
        val count = tracksAdded.incrementAndGet()
        if (count >= totalTracks.get() && !muxerStarted) {
            muxer?.start()
            muxerStarted = true
            Log.d(TAG, "Muxer started with $count tracks")
        }
    }

    private fun drainVideoEncoder(endOfStream: Boolean) {
        val encoder = this.videoEncoder ?: return

        if (endOfStream) {
            val inputBufferIndex = encoder.dequeueInputBuffer(TIMEOUT_US)
            if (inputBufferIndex >= 0) {
                encoder.queueInputBuffer(
                    inputBufferIndex,
                    0,
                    0,
                    (System.nanoTime() - startTimeNs) / 1000,
                    MediaCodec.BUFFER_FLAG_END_OF_STREAM
                )
            }
        }

        val bufferInfo = MediaCodec.BufferInfo()

        while (true) {
            val outputBufferIndex = encoder.dequeueOutputBuffer(bufferInfo, TIMEOUT_US)

            when {
                outputBufferIndex == MediaCodec.INFO_TRY_AGAIN_LATER -> {
                    if (!endOfStream) break
                }
                outputBufferIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                    synchronized(muxerLock) {
                        val newFormat = encoder.outputFormat
                        videoTrackIndex = muxer?.addTrack(newFormat) ?: -1
                        Log.d(TAG, "Video track added: $videoTrackIndex")
                        checkAndStartMuxer()
                    }
                }
                outputBufferIndex >= 0 -> {
                    val outputBuffer = encoder.getOutputBuffer(outputBufferIndex)

                    synchronized(muxerLock) {
                        if (outputBuffer != null && muxerStarted && videoTrackIndex >= 0) {
                            if ((bufferInfo.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG) != 0) {
                                bufferInfo.size = 0
                            }

                            if (bufferInfo.size > 0) {
                                outputBuffer.position(bufferInfo.offset)
                                outputBuffer.limit(bufferInfo.offset + bufferInfo.size)
                                muxer?.writeSampleData(videoTrackIndex, outputBuffer, bufferInfo)
                            }
                        }
                    }

                    encoder.releaseOutputBuffer(outputBufferIndex, false)

                    if ((bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
                        break
                    }
                }
            }
        }
    }

    fun stop(completion: (String?) -> Unit) {
        if (!isRecording.getAndSet(false)) {
            completion(null)
            return
        }

        // Wait for audio thread to finish
        audioThread?.join(1000)
        audioThread = null

        videoEncoderHandler?.post {
            try {
                // Drain remaining video frames
                drainVideoEncoder(true)

                // Drain remaining audio
                drainAudioEncoder(true)

                // Release video encoder
                videoEncoder?.stop()
                videoEncoder?.release()
                videoEncoder = null

                // Release audio encoder
                audioEncoder?.stop()
                audioEncoder?.release()
                audioEncoder = null

                // Release audio record
                audioRecord?.release()
                audioRecord = null

                // Release muxer
                synchronized(muxerLock) {
                    if (muxerStarted) {
                        muxer?.stop()
                    }
                    muxer?.release()
                    muxer = null
                    muxerStarted = false
                }

                // Save to gallery on main thread
                outputFile?.let { file ->
                    if (file.exists() && file.length() > 0) {
                        saveToGallery(file)
                        Handler(context.mainLooper).post {
                            completion(file.absolutePath)
                        }
                    } else {
                        Handler(context.mainLooper).post {
                            completion(null)
                        }
                    }
                } ?: Handler(context.mainLooper).post {
                    completion(null)
                }

                Log.d(TAG, "Video recording stopped. Frames encoded: $frameCount")

            } catch (e: Exception) {
                Log.e(TAG, "Error stopping video recording", e)
                Handler(context.mainLooper).post {
                    completion(null)
                }
            } finally {
                cleanup()
            }
        }
    }

    private fun cleanup() {
        videoEncoderThread?.quitSafely()
        videoEncoderThread = null
        videoEncoderHandler = null
        tracksAdded.set(0)
        videoTrackIndex = -1
        audioTrackIndex = -1
    }

    private fun saveToGallery(file: File) {
        try {
            val contentValues = ContentValues().apply {
                put(MediaStore.Video.Media.DISPLAY_NAME, file.name)
                put(MediaStore.Video.Media.MIME_TYPE, "video/mp4")
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    put(MediaStore.Video.Media.RELATIVE_PATH, "Movies/DualMoza")
                    put(MediaStore.Video.Media.IS_PENDING, 1)
                }
            }

            val uri = context.contentResolver.insert(
                MediaStore.Video.Media.EXTERNAL_CONTENT_URI,
                contentValues
            )

            uri?.let {
                context.contentResolver.openOutputStream(it)?.use { out ->
                    file.inputStream().use { input ->
                        input.copyTo(out)
                    }
                }

                // Mark as complete on Android Q+
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    contentValues.clear()
                    contentValues.put(MediaStore.Video.Media.IS_PENDING, 0)
                    context.contentResolver.update(it, contentValues, null, null)
                }

                Log.d(TAG, "Video saved to gallery: $uri")
            }

            // Delete temp file
            file.delete()

        } catch (e: Exception) {
            Log.e(TAG, "Error saving video to gallery", e)
        }
    }
}
