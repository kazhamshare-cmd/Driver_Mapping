package com.dualmoza.app.camera

import android.content.ContentValues
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.ImageFormat
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.graphics.RectF
import android.hardware.camera2.*
import android.media.ImageReader
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.provider.MediaStore
import android.util.Log
import android.view.Surface
import android.view.WindowManager
import java.text.SimpleDateFormat
import java.util.*
import java.util.concurrent.Semaphore
import java.util.concurrent.TimeUnit

/**
 * Camera Manager supporting both single and dual camera modes.
 * Automatically detects dual camera support and falls back to single camera mode if not available.
 */
class DualCameraManager(private val context: Context) {

    companion object {
        private const val TAG = "DualCameraManager"
        private const val PREVIEW_WIDTH = 640
        private const val PREVIEW_HEIGHT = 480
    }

    // Camera IDs
    private var frontCameraId: String? = null
    private var backCameraId: String? = null

    // Camera characteristics for rotation
    private var frontSensorOrientation: Int = 0
    private var backSensorOrientation: Int = 0

    // Dual camera mode - separate devices and sessions
    private var frontCameraDevice: CameraDevice? = null
    private var backCameraDevice: CameraDevice? = null
    private var frontCaptureSession: CameraCaptureSession? = null
    private var backCaptureSession: CameraCaptureSession? = null
    private var frontImageReader: ImageReader? = null
    private var backImageReader: ImageReader? = null

    // Single camera mode - shared references
    private var activeCameraDevice: CameraDevice? = null
    private var activeCaptureSession: CameraCaptureSession? = null
    private var activeImageReader: ImageReader? = null

    // Background handlers
    private var backgroundThread: HandlerThread? = null
    private var backgroundHandler: Handler? = null

    // Camera manager
    private val cameraManager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager

    // Camera open lock
    private val cameraOpenCloseLock = Semaphore(2)

    // Callback for preview frames
    private var previewCallback: ((Bitmap?, Bitmap?) -> Unit)? = null

    // Latest preview bitmaps
    private var latestFrontBitmap: Bitmap? = null
    private var latestBackBitmap: Bitmap? = null
    private var latestFrontProcessed: Bitmap? = null
    private var latestBackProcessed: Bitmap? = null

    // Face detectors - one for each camera in dual mode
    private val frontFaceDetector = FaceDetector()
    private val backFaceDetector = FaceDetector()

    // Person detectors - for person detection mode
    private val frontPersonDetector = PersonDetector()
    private val backPersonDetector = PersonDetector()

    // Detection mode
    var detectionMode: com.dualmoza.app.data.DetectionMode = com.dualmoza.app.data.DetectionMode.FACE_ONLY

    // Privacy filter settings (applied to both cameras)
    var mosaicEnabled: Boolean = true
        set(value) {
            field = value
            frontFaceDetector.mosaicEnabled = value
            backFaceDetector.mosaicEnabled = value
            frontPersonDetector.mosaicEnabled = value
            backPersonDetector.mosaicEnabled = value
        }

    var privacyFilterType: com.dualmoza.app.data.PrivacyFilterType = com.dualmoza.app.data.PrivacyFilterType.MOSAIC
        set(value) {
            field = value
            frontFaceDetector.privacyFilterType = value
            backFaceDetector.privacyFilterType = value
            frontPersonDetector.privacyFilterType = value
            backPersonDetector.privacyFilterType = value
        }

    var mosaicIntensity: Int = 15
        set(value) {
            field = value
            frontFaceDetector.mosaicIntensity = value
            backFaceDetector.mosaicIntensity = value
            frontPersonDetector.mosaicIntensity = value
            backPersonDetector.mosaicIntensity = value
        }

    var mosaicMode: FaceDetector.MosaicMode = FaceDetector.MosaicMode.EYES_ONLY
        set(value) {
            field = value
            frontFaceDetector.mosaicMode = value
            backFaceDetector.mosaicMode = value
        }

    var mosaicCoverage: Float = 0.5f
        set(value) {
            field = value
            frontFaceDetector.mosaicCoverage = value
            backFaceDetector.mosaicCoverage = value
        }

    // Recording state
    private var isRecording = false
    private var videoRecorder: VideoRecorder? = null

    // Dual camera support
    var supportsDualCamera: Boolean = false
        private set

    // Is dual mode currently active
    var isDualModeActive: Boolean = false
        private set

    // Current active camera (for single mode)
    var isUsingFrontCamera = true
        private set

    // Camera state
    private var isCameraRunning = false

    // Zoom settings
    private var currentZoomLevel = 1.0f
    private var maxZoomLevel = 1.0f
    private var frontMaxZoom = 1.0f
    private var backMaxZoom = 1.0f
    private var frontSensorRect: android.graphics.Rect? = null
    private var backSensorRect: android.graphics.Rect? = null
    private var activeCaptureRequestBuilder: CaptureRequest.Builder? = null
    private var frontCaptureRequestBuilder: CaptureRequest.Builder? = null
    private var backCaptureRequestBuilder: CaptureRequest.Builder? = null

    init {
        findCameras()
        checkDualCameraSupport()
    }

    private fun findCameras() {
        try {
            for (cameraId in cameraManager.cameraIdList) {
                val characteristics = cameraManager.getCameraCharacteristics(cameraId)
                val facing = characteristics.get(CameraCharacteristics.LENS_FACING)
                val sensorOrientation = characteristics.get(CameraCharacteristics.SENSOR_ORIENTATION) ?: 0
                val maxDigitalZoom = characteristics.get(CameraCharacteristics.SCALER_AVAILABLE_MAX_DIGITAL_ZOOM) ?: 1.0f
                val sensorRect = characteristics.get(CameraCharacteristics.SENSOR_INFO_ACTIVE_ARRAY_SIZE)

                when (facing) {
                    CameraCharacteristics.LENS_FACING_FRONT -> {
                        frontCameraId = cameraId
                        frontSensorOrientation = sensorOrientation
                        frontMaxZoom = maxDigitalZoom
                        frontSensorRect = sensorRect
                    }
                    CameraCharacteristics.LENS_FACING_BACK -> {
                        backCameraId = cameraId
                        backSensorOrientation = sensorOrientation
                        backMaxZoom = maxDigitalZoom
                        backSensorRect = sensorRect
                    }
                }
            }
            Log.d(TAG, "Found cameras - Front: $frontCameraId (${frontSensorOrientation}°, zoom: ${frontMaxZoom}x), Back: $backCameraId (${backSensorOrientation}°, zoom: ${backMaxZoom}x)")
        } catch (e: CameraAccessException) {
            Log.e(TAG, "Error finding cameras", e)
        }
    }

    private fun checkDualCameraSupport() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            try {
                val concurrentCameraIds = cameraManager.concurrentCameraIds
                for (cameraIdSet in concurrentCameraIds) {
                    if (frontCameraId in cameraIdSet && backCameraId in cameraIdSet) {
                        supportsDualCamera = true
                        Log.d(TAG, "Dual camera supported!")
                        return
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error checking dual camera support", e)
            }
        }
        supportsDualCamera = false
        Log.d(TAG, "Dual camera not supported, using single camera mode")
    }

    fun setPreviewCallback(callback: (Bitmap?, Bitmap?) -> Unit) {
        previewCallback = callback
    }

    fun startCamera() {
        if (isCameraRunning) return
        isCameraRunning = true
        startBackgroundThread()

        if (supportsDualCamera) {
            startDualCameraMode()
        } else {
            startSingleCameraMode(isUsingFrontCamera)
        }
    }

    fun stopCamera() {
        isCameraRunning = false
        if (isDualModeActive) {
            closeDualCameras()
        } else {
            closeSingleCamera()
        }
        stopBackgroundThread()
        frontFaceDetector.close()
        backFaceDetector.close()
        frontPersonDetector.close()
        backPersonDetector.close()
    }

    fun switchCamera() {
        if (!isCameraRunning) return

        if (isDualModeActive) {
            // In dual mode, switch toggles which camera is "main"
            // This is handled by the UI layer
            return
        }

        // Single camera mode - switch between front and back
        isUsingFrontCamera = !isUsingFrontCamera
        latestFrontBitmap = null
        latestBackBitmap = null
        currentZoomLevel = 1.0f  // Reset zoom when switching

        backgroundHandler?.post {
            closeSingleCamera()
            startSingleCameraMode(isUsingFrontCamera)
        }
    }

    // MARK: - Zoom Control

    fun getMaxZoom(): Float {
        return if (isDualModeActive) {
            backMaxZoom  // Use back camera max zoom in dual mode
        } else {
            if (isUsingFrontCamera) frontMaxZoom else backMaxZoom
        }
    }

    fun getCurrentZoom(): Float = currentZoomLevel

    fun setZoom(zoomLevel: Float) {
        val maxZoom = getMaxZoom()
        currentZoomLevel = zoomLevel.coerceIn(1.0f, maxZoom)
        applyZoom()
    }

    fun zoomIn(step: Float = 0.5f) {
        setZoom(currentZoomLevel + step)
    }

    fun zoomOut(step: Float = 0.5f) {
        setZoom(currentZoomLevel - step)
    }

    private fun applyZoom() {
        backgroundHandler?.post {
            try {
                if (isDualModeActive) {
                    // Apply zoom to back camera in dual mode
                    applyZoomToCamera(backCaptureRequestBuilder, backCaptureSession, backSensorRect, backMaxZoom)
                } else {
                    val sensorRect = if (isUsingFrontCamera) frontSensorRect else backSensorRect
                    val maxZoom = if (isUsingFrontCamera) frontMaxZoom else backMaxZoom
                    applyZoomToCamera(activeCaptureRequestBuilder, activeCaptureSession, sensorRect, maxZoom)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error applying zoom", e)
            }
        }
    }

    private fun applyZoomToCamera(
        requestBuilder: CaptureRequest.Builder?,
        session: CameraCaptureSession?,
        sensorRect: android.graphics.Rect?,
        maxZoom: Float
    ) {
        if (requestBuilder == null || session == null || sensorRect == null) return

        val zoomLevel = currentZoomLevel.coerceIn(1.0f, maxZoom)
        val centerX = sensorRect.width() / 2
        val centerY = sensorRect.height() / 2
        val deltaX = ((sensorRect.width() / zoomLevel) / 2).toInt()
        val deltaY = ((sensorRect.height() / zoomLevel) / 2).toInt()

        val cropRect = android.graphics.Rect(
            centerX - deltaX,
            centerY - deltaY,
            centerX + deltaX,
            centerY + deltaY
        )

        requestBuilder.set(CaptureRequest.SCALER_CROP_REGION, cropRect)

        try {
            session.setRepeatingRequest(requestBuilder.build(), null, backgroundHandler)
            Log.d(TAG, "Zoom applied: ${zoomLevel}x")
        } catch (e: CameraAccessException) {
            Log.e(TAG, "Error setting zoom", e)
        }
    }

    // MARK: - Single Camera Mode

    private fun startSingleCameraMode(useFront: Boolean) {
        isDualModeActive = false
        val cameraId = if (useFront) frontCameraId else backCameraId

        if (cameraId == null) {
            Log.e(TAG, "Camera not available")
            return
        }

        openSingleCamera(cameraId, useFront)
    }

    private fun openSingleCamera(cameraId: String, isFront: Boolean) {
        try {
            if (!cameraOpenCloseLock.tryAcquire(2500, TimeUnit.MILLISECONDS)) {
                throw RuntimeException("Time out waiting to lock camera opening.")
            }

            val sensorOrientation = if (isFront) frontSensorOrientation else backSensorOrientation

            activeImageReader = ImageReader.newInstance(
                PREVIEW_WIDTH, PREVIEW_HEIGHT, ImageFormat.YUV_420_888, 2
            ).apply {
                setOnImageAvailableListener({ reader ->
                    processFrame(reader, sensorOrientation, isFront, isFront)
                }, backgroundHandler)
            }

            cameraManager.openCamera(cameraId, object : CameraDevice.StateCallback() {
                override fun onOpened(camera: CameraDevice) {
                    cameraOpenCloseLock.release()
                    activeCameraDevice = camera
                    createSingleCaptureSession(camera, activeImageReader!!)
                    Log.d(TAG, "Single camera opened: ${if (isFront) "Front" else "Back"}")
                }

                override fun onDisconnected(camera: CameraDevice) {
                    cameraOpenCloseLock.release()
                    camera.close()
                    activeCameraDevice = null
                }

                override fun onError(camera: CameraDevice, error: Int) {
                    cameraOpenCloseLock.release()
                    camera.close()
                    activeCameraDevice = null
                    Log.e(TAG, "Camera error: $error")
                }
            }, backgroundHandler)
        } catch (e: Exception) {
            cameraOpenCloseLock.release()
            Log.e(TAG, "Error opening single camera", e)
        }
    }

    private fun createSingleCaptureSession(camera: CameraDevice, imageReader: ImageReader) {
        try {
            val surface = imageReader.surface
            val captureRequestBuilder = camera.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW)
            captureRequestBuilder.addTarget(surface)
            captureRequestBuilder.set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_VIDEO)
            captureRequestBuilder.set(CaptureRequest.CONTROL_AE_MODE, CaptureRequest.CONTROL_AE_MODE_ON)

            // Store the builder for zoom control
            activeCaptureRequestBuilder = captureRequestBuilder

            // Update max zoom for current camera
            maxZoomLevel = if (isUsingFrontCamera) frontMaxZoom else backMaxZoom
            currentZoomLevel = 1.0f

            camera.createCaptureSession(
                listOf(surface),
                object : CameraCaptureSession.StateCallback() {
                    override fun onConfigured(session: CameraCaptureSession) {
                        if (activeCameraDevice == null) return
                        activeCaptureSession = session
                        try {
                            session.setRepeatingRequest(captureRequestBuilder.build(), null, backgroundHandler)
                            Log.d(TAG, "Single camera preview started, max zoom: ${maxZoomLevel}x")
                        } catch (e: CameraAccessException) {
                            Log.e(TAG, "Error starting preview", e)
                        }
                    }

                    override fun onConfigureFailed(session: CameraCaptureSession) {
                        Log.e(TAG, "Capture session configuration failed")
                    }
                },
                backgroundHandler
            )
        } catch (e: CameraAccessException) {
            Log.e(TAG, "Error creating capture session", e)
        }
    }

    private fun closeSingleCamera() {
        try {
            cameraOpenCloseLock.acquire()
            activeCaptureSession?.close()
            activeCaptureSession = null
            activeCameraDevice?.close()
            activeCameraDevice = null
            activeImageReader?.close()
            activeImageReader = null
        } catch (e: InterruptedException) {
            Log.e(TAG, "Interrupted while closing camera", e)
        } finally {
            cameraOpenCloseLock.release()
        }
    }

    // MARK: - Dual Camera Mode

    private fun startDualCameraMode() {
        isDualModeActive = true

        if (frontCameraId == null || backCameraId == null) {
            Log.e(TAG, "Both cameras required for dual mode")
            startSingleCameraMode(true)
            return
        }

        // Open both cameras
        openDualCamera(frontCameraId!!, true)
        openDualCamera(backCameraId!!, false)
    }

    private fun openDualCamera(cameraId: String, isFront: Boolean) {
        try {
            if (!cameraOpenCloseLock.tryAcquire(2500, TimeUnit.MILLISECONDS)) {
                throw RuntimeException("Time out waiting to lock camera opening.")
            }

            val sensorOrientation = if (isFront) frontSensorOrientation else backSensorOrientation

            val imageReader = ImageReader.newInstance(
                PREVIEW_WIDTH, PREVIEW_HEIGHT, ImageFormat.YUV_420_888, 2
            ).apply {
                setOnImageAvailableListener({ reader ->
                    processFrame(reader, sensorOrientation, isFront, isFront)
                }, backgroundHandler)
            }

            if (isFront) {
                frontImageReader = imageReader
            } else {
                backImageReader = imageReader
            }

            cameraManager.openCamera(cameraId, object : CameraDevice.StateCallback() {
                override fun onOpened(camera: CameraDevice) {
                    cameraOpenCloseLock.release()
                    if (isFront) {
                        frontCameraDevice = camera
                    } else {
                        backCameraDevice = camera
                    }
                    createDualCaptureSession(camera, imageReader, isFront)
                    Log.d(TAG, "Dual camera opened: ${if (isFront) "Front" else "Back"}")
                }

                override fun onDisconnected(camera: CameraDevice) {
                    cameraOpenCloseLock.release()
                    camera.close()
                    if (isFront) frontCameraDevice = null else backCameraDevice = null
                }

                override fun onError(camera: CameraDevice, error: Int) {
                    cameraOpenCloseLock.release()
                    camera.close()
                    if (isFront) frontCameraDevice = null else backCameraDevice = null
                    Log.e(TAG, "Dual camera error: $error")

                    // Fall back to single camera mode
                    if (isDualModeActive) {
                        Log.w(TAG, "Falling back to single camera mode due to error")
                        closeDualCameras()
                        isDualModeActive = false
                        supportsDualCamera = false
                        startSingleCameraMode(true)
                    }
                }
            }, backgroundHandler)
        } catch (e: Exception) {
            cameraOpenCloseLock.release()
            Log.e(TAG, "Error opening dual camera", e)

            // Fall back to single camera
            if (isDualModeActive) {
                isDualModeActive = false
                supportsDualCamera = false
                startSingleCameraMode(true)
            }
        }
    }

    private fun createDualCaptureSession(camera: CameraDevice, imageReader: ImageReader, isFront: Boolean) {
        try {
            val surface = imageReader.surface
            val captureRequestBuilder = camera.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW)
            captureRequestBuilder.addTarget(surface)
            captureRequestBuilder.set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_VIDEO)
            captureRequestBuilder.set(CaptureRequest.CONTROL_AE_MODE, CaptureRequest.CONTROL_AE_MODE_ON)

            // Store the builder for zoom control
            if (isFront) {
                frontCaptureRequestBuilder = captureRequestBuilder
            } else {
                backCaptureRequestBuilder = captureRequestBuilder
                maxZoomLevel = backMaxZoom
                currentZoomLevel = 1.0f
            }

            camera.createCaptureSession(
                listOf(surface),
                object : CameraCaptureSession.StateCallback() {
                    override fun onConfigured(session: CameraCaptureSession) {
                        val cameraDevice = if (isFront) frontCameraDevice else backCameraDevice
                        if (cameraDevice == null) return

                        if (isFront) {
                            frontCaptureSession = session
                        } else {
                            backCaptureSession = session
                        }

                        try {
                            session.setRepeatingRequest(captureRequestBuilder.build(), null, backgroundHandler)
                            val maxZoom = if (isFront) frontMaxZoom else backMaxZoom
                            Log.d(TAG, "Dual camera ${if (isFront) "front" else "back"} preview started, max zoom: ${maxZoom}x")
                        } catch (e: CameraAccessException) {
                            Log.e(TAG, "Error starting dual preview", e)
                        }
                    }

                    override fun onConfigureFailed(session: CameraCaptureSession) {
                        Log.e(TAG, "Dual capture session configuration failed")
                    }
                },
                backgroundHandler
            )
        } catch (e: CameraAccessException) {
            Log.e(TAG, "Error creating dual capture session", e)
        }
    }

    private fun closeDualCameras() {
        try {
            cameraOpenCloseLock.acquire(2)

            frontCaptureSession?.close()
            frontCaptureSession = null
            backCaptureSession?.close()
            backCaptureSession = null

            frontCameraDevice?.close()
            frontCameraDevice = null
            backCameraDevice?.close()
            backCameraDevice = null

            frontImageReader?.close()
            frontImageReader = null
            backImageReader?.close()
            backImageReader = null

        } catch (e: InterruptedException) {
            Log.e(TAG, "Interrupted while closing dual cameras", e)
        } finally {
            cameraOpenCloseLock.release(2)
        }
    }

    // MARK: - Frame Processing

    private fun processFrame(reader: ImageReader, sensorOrientation: Int, isFront: Boolean, useFrontDetector: Boolean) {
        try {
            val image = reader.acquireLatestImage() ?: return
            image.use {
                val bitmap = imageToBitmap(it, sensorOrientation, isFront)

                // Store raw bitmap
                if (isFront) {
                    latestFrontBitmap = bitmap
                } else {
                    latestBackBitmap = bitmap
                }

                // Process with appropriate detector based on detection mode
                val processCallback: (Bitmap) -> Unit = { processedBitmap ->
                    if (isFront) {
                        latestFrontProcessed = processedBitmap
                    } else {
                        latestBackProcessed = processedBitmap
                    }

                    // Add frame to video recorder if recording
                    if (isRecording && isDualModeActive) {
                        // Composite both cameras for recording
                        val composite = createCompositeBitmap()
                        composite?.let { videoRecorder?.addFrame(it) }
                    } else if (isRecording) {
                        videoRecorder?.addFrame(processedBitmap)
                    }

                    // Notify callback with both camera previews
                    if (isDualModeActive) {
                        previewCallback?.invoke(latestFrontProcessed, latestBackProcessed)
                    } else {
                        if (isFront) {
                            previewCallback?.invoke(processedBitmap, null)
                        } else {
                            previewCallback?.invoke(null, processedBitmap)
                        }
                    }
                }

                // Select detector based on detection mode
                when (detectionMode) {
                    com.dualmoza.app.data.DetectionMode.PERSON_DETECTION -> {
                        val detector = if (useFrontDetector) frontPersonDetector else backPersonDetector
                        detector.processFrame(bitmap, processCallback)
                    }
                    com.dualmoza.app.data.DetectionMode.FACE_ONLY -> {
                        val detector = if (useFrontDetector) frontFaceDetector else backFaceDetector
                        detector.processFrame(bitmap, processCallback)
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error processing frame", e)
        }
    }

    private fun createCompositeBitmap(): Bitmap? {
        val front = latestFrontProcessed ?: return null
        val back = latestBackProcessed ?: return null

        // Create a composite with back camera as main and front as PiP
        val width = back.width
        val height = back.height
        val composite = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(composite)

        // Draw back camera as main
        canvas.drawBitmap(back, 0f, 0f, null)

        // Draw front camera as PiP (top-left corner, 25% width, preserve aspect ratio)
        val pipWidth = (width * 0.25f).toInt()
        // Calculate PiP height based on front camera aspect ratio (typically 4:3 or 16:9)
        val frontAspect = front.width.toFloat() / front.height
        val pipHeight = (pipWidth / frontAspect).toInt()

        val pipX = 20f
        val pipY = 80f

        // Scale front camera to PiP size while preserving aspect ratio
        val scaledFront = scaleAndCropToFill(front, pipWidth, pipHeight)
        canvas.drawBitmap(scaledFront, pipX, pipY, null)
        scaledFront.recycle()

        return composite
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

    // MARK: - Helper Methods

    private fun startBackgroundThread() {
        backgroundThread = HandlerThread("CameraBackground").also { it.start() }
        backgroundHandler = Handler(backgroundThread!!.looper)
    }

    private fun stopBackgroundThread() {
        backgroundThread?.quitSafely()
        try {
            backgroundThread?.join()
            backgroundThread = null
            backgroundHandler = null
        } catch (e: InterruptedException) {
            Log.e(TAG, "Error stopping background thread", e)
        }
    }

    private fun getDisplayRotation(): Int {
        return try {
            val windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                context.display?.rotation ?: Surface.ROTATION_0
            } else {
                @Suppress("DEPRECATION")
                windowManager.defaultDisplay.rotation
            }
        } catch (e: Exception) {
            Surface.ROTATION_0
        }
    }

    private fun imageToBitmap(image: android.media.Image, sensorOrientation: Int, isFront: Boolean): Bitmap {
        val yBuffer = image.planes[0].buffer
        val uBuffer = image.planes[1].buffer
        val vBuffer = image.planes[2].buffer

        val ySize = yBuffer.remaining()
        val uSize = uBuffer.remaining()
        val vSize = vBuffer.remaining()

        val nv21 = ByteArray(ySize + uSize + vSize)
        yBuffer.get(nv21, 0, ySize)
        vBuffer.get(nv21, ySize, vSize)
        uBuffer.get(nv21, ySize + vSize, uSize)

        val yuvImage = android.graphics.YuvImage(
            nv21, ImageFormat.NV21, image.width, image.height, null
        )
        val out = java.io.ByteArrayOutputStream()
        yuvImage.compressToJpeg(android.graphics.Rect(0, 0, image.width, image.height), 85, out)
        val imageBytes = out.toByteArray()
        val bitmap = android.graphics.BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.size)

        // Calculate rotation
        val displayRotation = getDisplayRotation()
        val degrees = when (displayRotation) {
            Surface.ROTATION_0 -> 0
            Surface.ROTATION_90 -> 90
            Surface.ROTATION_180 -> 180
            Surface.ROTATION_270 -> 270
            else -> 0
        }

        val rotation = if (isFront) {
            (sensorOrientation + degrees) % 360
        } else {
            (sensorOrientation - degrees + 360) % 360
        }

        val matrix = Matrix()
        matrix.postRotate(rotation.toFloat())
        if (isFront) {
            matrix.postScale(-1f, 1f, bitmap.width / 2f, bitmap.height / 2f)
        }

        return Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
    }

    // MARK: - Recording

    fun startRecording(isPro: Boolean) {
        if (isRecording) return
        isRecording = true

        videoRecorder = VideoRecorder(context, isPro).apply {
            start()
        }
        Log.d(TAG, "Recording started")
    }

    fun stopRecording(completion: (String?) -> Unit) {
        if (!isRecording) {
            completion(null)
            return
        }
        isRecording = false

        videoRecorder?.stop { filePath ->
            completion(filePath)
        }
        videoRecorder = null
        Log.d(TAG, "Recording stopped")
    }

    // MARK: - Photo Capture

    fun capturePhoto(isPro: Boolean, completion: (Bitmap?) -> Unit) {
        val bitmap = if (isDualModeActive) {
            createCompositeBitmap()
        } else {
            latestFrontProcessed ?: latestBackProcessed
        }

        if (bitmap != null) {
            val outputBitmap = addWatermarkIfNeeded(bitmap, isPro)
            saveBitmapToGallery(outputBitmap)
            completion(outputBitmap)
        } else {
            completion(null)
        }
    }

    private fun addWatermarkIfNeeded(bitmap: Bitmap, isPro: Boolean): Bitmap {
        if (isPro) return bitmap

        val width = bitmap.width
        val height = bitmap.height

        val output = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(output)
        canvas.drawBitmap(bitmap, 0f, 0f, null)

        val paint = Paint().apply {
            color = android.graphics.Color.argb(128, 255, 255, 255)
            textSize = (height * 0.03f).coerceAtLeast(30f)
            isAntiAlias = true
        }
        val text = "DualMoza"
        val textWidth = paint.measureText(text)
        canvas.drawText(text, width - textWidth - 20f, height - 30f, paint)

        return output
    }

    private fun saveBitmapToGallery(bitmap: Bitmap) {
        try {
            val dateFormat = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault())
            val fileName = "DualMoza_${dateFormat.format(Date())}.jpg"

            val contentValues = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                put(MediaStore.MediaColumns.MIME_TYPE, "image/jpeg")
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    put(MediaStore.MediaColumns.RELATIVE_PATH, "Pictures/DualMoza")
                }
            }

            val uri = context.contentResolver.insert(
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                contentValues
            )

            uri?.let {
                context.contentResolver.openOutputStream(it)?.use { out ->
                    bitmap.compress(Bitmap.CompressFormat.JPEG, 95, out)
                }
            }
            Log.d(TAG, "Photo saved: $fileName")
        } catch (e: Exception) {
            Log.e(TAG, "Error saving photo", e)
        }
    }
}
