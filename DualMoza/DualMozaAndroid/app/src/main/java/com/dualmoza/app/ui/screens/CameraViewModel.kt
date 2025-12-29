package com.dualmoza.app.ui.screens

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.provider.MediaStore
import androidx.compose.ui.geometry.Offset
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.dualmoza.app.R
import com.dualmoza.app.ads.AdManager
import com.dualmoza.app.billing.BillingManager
import com.dualmoza.app.camera.DualCameraManager
import com.dualmoza.app.data.*
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class CameraViewModel @Inject constructor() : ViewModel() {

    private val appStateManager = AppStateManager()

    // Billing and Ads
    private var billingManager: BillingManager? = null
    private var adManager: AdManager? = null

    // Expose app state
    val appState = MutableStateFlow(Unit)
    val frontCamera = appStateManager.frontCamera
    val backCamera = appStateManager.backCamera
    val pipSettings = appStateManager.pipSettings
    val mainCameraIsBack = appStateManager.mainCameraIsBack
    val captureMode = appStateManager.captureMode
    val isRecording = appStateManager.isRecording
    val recordingDuration = appStateManager.recordingDuration
    val isPro = appStateManager.isPro
    val needsToWatchAd = appStateManager.needsToWatchAd
    val freeRecordingLimit = appStateManager.freeRecordingLimit

    // Camera previews
    private val _frontCameraPreview = MutableStateFlow<Bitmap?>(null)
    val frontCameraPreview: StateFlow<Bitmap?> = _frontCameraPreview.asStateFlow()

    private val _backCameraPreview = MutableStateFlow<Bitmap?>(null)
    val backCameraPreview: StateFlow<Bitmap?> = _backCameraPreview.asStateFlow()

    // Dual camera support
    private val _supportsDualCamera = MutableStateFlow(false)
    val supportsDualCamera: StateFlow<Boolean> = _supportsDualCamera.asStateFlow()

    private val _isDualModeActive = MutableStateFlow(false)
    val isDualModeActive: StateFlow<Boolean> = _isDualModeActive.asStateFlow()

    // Privacy filter settings
    private val _mosaicEnabled = MutableStateFlow(true)
    val mosaicEnabled: StateFlow<Boolean> = _mosaicEnabled.asStateFlow()

    private val _privacyFilterType = MutableStateFlow(PrivacyFilterType.MOSAIC)
    val privacyFilterType: StateFlow<PrivacyFilterType> = _privacyFilterType.asStateFlow()

    private val _mosaicIntensity = MutableStateFlow(15)
    val mosaicIntensity: StateFlow<Int> = _mosaicIntensity.asStateFlow()

    private val _mosaicMode = MutableStateFlow(com.dualmoza.app.camera.FaceDetector.MosaicMode.EYES_ONLY)
    val mosaicMode: StateFlow<com.dualmoza.app.camera.FaceDetector.MosaicMode> = _mosaicMode.asStateFlow()

    private val _mosaicCoverage = MutableStateFlow(0.5f)
    val mosaicCoverage: StateFlow<Float> = _mosaicCoverage.asStateFlow()

    private val _detectionMode = MutableStateFlow(DetectionMode.FACE_ONLY)
    val detectionMode: StateFlow<DetectionMode> = _detectionMode.asStateFlow()

    // Settings dialog
    private val _showSettings = MutableStateFlow(false)
    val showSettings: StateFlow<Boolean> = _showSettings.asStateFlow()

    // Capture feedback
    private val _captureEvent = MutableStateFlow<CaptureEvent?>(null)
    val captureEvent: StateFlow<CaptureEvent?> = _captureEvent.asStateFlow()

    sealed class CaptureEvent {
        object PhotoSaved : CaptureEvent()
        object VideoSaved : CaptureEvent()
        object CaptureFailed : CaptureEvent()
    }

    fun clearCaptureEvent() {
        _captureEvent.value = null
    }

    // Camera manager
    private var cameraManager: DualCameraManager? = null

    // Recording timer
    private var recordingTimerJob: Job? = null

    fun initializeCamera(context: Context) {
        // Initialize camera
        cameraManager = DualCameraManager(context)
        _supportsDualCamera.value = cameraManager?.supportsDualCamera ?: false
        cameraManager?.setPreviewCallback { frontBitmap, backBitmap ->
            _frontCameraPreview.value = frontBitmap
            _backCameraPreview.value = backBitmap
            _isDualModeActive.value = cameraManager?.isDualModeActive ?: false
        }
        cameraManager?.startCamera()

        // Initial zoom state update
        viewModelScope.launch {
            kotlinx.coroutines.delay(500) // Wait for camera to initialize
            updateZoomState()
        }

        // Initialize billing
        billingManager = BillingManager(context)
        viewModelScope.launch {
            billingManager?.isPro?.collect { isPro ->
                appStateManager.setIsPro(isPro)
            }
        }

        // Initialize ads
        adManager = AdManager(context)
    }

    fun toggleMainCamera() {
        appStateManager.toggleMainCamera()
    }

    fun switchCamera() {
        cameraManager?.switchCamera()
        appStateManager.toggleMainCamera()
    }

    // Toggle PiP (secondary camera on/off)
    fun togglePiP() {
        val mainIsBack = mainCameraIsBack.value
        if (mainIsBack) {
            // Main is back, secondary is front
            val currentFront = frontCamera.value
            val newMode = if (currentFront.mode == CameraMode.OFF) CameraMode.ON else CameraMode.OFF
            appStateManager.updateFrontCamera(currentFront.copy(mode = newMode))
        } else {
            // Main is front, secondary is back
            val currentBack = backCamera.value
            val newMode = if (currentBack.mode == CameraMode.OFF) CameraMode.ON else CameraMode.OFF
            appStateManager.updateBackCamera(currentBack.copy(mode = newMode))
        }
    }

    // Check if PiP is enabled
    val isPiPEnabled: Boolean
        get() {
            return if (mainCameraIsBack.value) {
                frontCamera.value.mode != CameraMode.OFF
            } else {
                backCamera.value.mode != CameraMode.OFF
            }
        }

    // Check if main camera is off
    val isMainCameraOff: Boolean
        get() {
            return if (mainCameraIsBack.value) {
                backCamera.value.mode == CameraMode.OFF
            } else {
                frontCamera.value.mode == CameraMode.OFF
            }
        }

    fun toggleMosaic() {
        _mosaicEnabled.value = !_mosaicEnabled.value
        cameraManager?.mosaicEnabled = _mosaicEnabled.value
    }

    fun setPrivacyFilterType(filterType: PrivacyFilterType) {
        _privacyFilterType.value = filterType
        cameraManager?.privacyFilterType = filterType
    }

    fun setMosaicIntensity(intensity: Int) {
        _mosaicIntensity.value = intensity
        cameraManager?.mosaicIntensity = intensity
    }

    fun setMosaicMode(mode: com.dualmoza.app.camera.FaceDetector.MosaicMode) {
        _mosaicMode.value = mode
        cameraManager?.mosaicMode = mode
    }

    fun setMosaicCoverage(coverage: Float) {
        _mosaicCoverage.value = coverage
        cameraManager?.mosaicCoverage = coverage
    }

    fun setDetectionMode(mode: DetectionMode) {
        _detectionMode.value = mode
        cameraManager?.detectionMode = mode
    }

    // Zoom control
    private val _currentZoom = MutableStateFlow(1.0f)
    val currentZoom: StateFlow<Float> = _currentZoom.asStateFlow()

    private val _maxZoom = MutableStateFlow(1.0f)
    val maxZoom: StateFlow<Float> = _maxZoom.asStateFlow()

    fun zoomIn() {
        cameraManager?.zoomIn(0.5f)
        updateZoomState()
    }

    fun zoomOut() {
        cameraManager?.zoomOut(0.5f)
        updateZoomState()
    }

    fun setZoom(level: Float) {
        cameraManager?.setZoom(level)
        updateZoomState()
    }

    private fun updateZoomState() {
        _currentZoom.value = cameraManager?.getCurrentZoom() ?: 1.0f
        _maxZoom.value = cameraManager?.getMaxZoom() ?: 1.0f
    }

    fun showSettings() {
        _showSettings.value = true
    }

    fun hideSettings() {
        _showSettings.value = false
    }

    fun setCaptureMode(mode: CaptureMode) {
        appStateManager.setCaptureMode(mode)
    }

    fun updatePiPPosition(position: Offset) {
        val current = pipSettings.value
        appStateManager.updatePiPSettings(current.copy(position = position))
    }

    fun toggleRecording() {
        android.util.Log.d("CameraViewModel", "toggleRecording called, isRecording=${isRecording.value}")
        if (isRecording.value) {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private fun startRecording() {
        android.util.Log.d("CameraViewModel", "startRecording called")

        // Check if user can start recording (may need to watch ad first)
        if (!appStateManager.canStartRecording()) {
            android.util.Log.d("CameraViewModel", "Cannot start recording - ad required")
            return
        }

        appStateManager.setRecording(true)

        // Start recording timer
        recordingTimerJob = viewModelScope.launch {
            while (isRecording.value) {
                delay(100)
                val newDuration = recordingDuration.value + 0.1
                appStateManager.updateRecordingDuration(newDuration)

                // Auto-stop for free version
                if (!isPro.value && newDuration >= freeRecordingLimit) {
                    stopRecording()
                }
            }
        }

        // Start actual recording
        cameraManager?.startRecording(isPro.value)
    }

    private fun stopRecording() {
        recordingTimerJob?.cancel()
        appStateManager.setRecording(false)

        // Stop actual recording
        cameraManager?.stopRecording { url ->
            // Save to gallery
            if (url != null) {
                _captureEvent.value = CaptureEvent.VideoSaved
            } else {
                _captureEvent.value = CaptureEvent.CaptureFailed
            }
            appStateManager.onRecordingFinished()
        }
    }

    fun capturePhoto() {
        android.util.Log.d("CameraViewModel", "capturePhoto called")
        cameraManager?.capturePhoto(isPro.value) { bitmap ->
            if (bitmap != null) {
                // Save to gallery
                appStateManager.onPhotoTaken()
                _captureEvent.value = CaptureEvent.PhotoSaved
            } else {
                _captureEvent.value = CaptureEvent.CaptureFailed
            }
        }
    }

    fun openGallery(context: Context) {
        val intent = Intent(Intent.ACTION_VIEW).apply {
            type = "image/*"
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        context.startActivity(Intent.createChooser(intent, context.getString(R.string.open_gallery)))
    }

    fun watchAd(context: Context) {
        val activity = context as? Activity
        if (activity != null && adManager?.isReady() == true) {
            adManager?.showRewardedAd(activity) {
                // User earned reward
                appStateManager.onAdWatched()
            }
        } else {
            // Ad not ready, just dismiss for now
            appStateManager.onAdWatched()
            // Try to load a new ad
            adManager?.loadRewardedAd()
        }
    }

    fun upgradeToPro(context: Context) {
        // すでにProの場合は何もしない
        if (isPro.value) {
            android.widget.Toast.makeText(
                context,
                context.getString(R.string.already_pro),
                android.widget.Toast.LENGTH_SHORT
            ).show()
            return
        }

        val activity = context as? Activity
        if (activity != null) {
            val success = billingManager?.launchPurchaseFlow(activity) ?: false
            if (!success) {
                // Show toast if billing not ready
                android.widget.Toast.makeText(
                    context,
                    context.getString(R.string.billing_unavailable),
                    android.widget.Toast.LENGTH_SHORT
                ).show()
            }
        }
    }

    override fun onCleared() {
        super.onCleared()
        cameraManager?.stopCamera()
        billingManager?.endConnection()
    }
}
