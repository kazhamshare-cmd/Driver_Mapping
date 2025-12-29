package com.dualmoza.app.data

import android.graphics.Bitmap
import androidx.compose.ui.geometry.Offset
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

// Camera Mode
enum class CameraMode {
    ON, OFF, STATIC_IMAGE
}

// PiP Shape
enum class PiPShape {
    CIRCLE, RECTANGLE
}

// Privacy Filter Type
enum class PrivacyFilterType {
    MOSAIC, BLUR
}

// Detection Mode
enum class DetectionMode {
    FACE_ONLY, PERSON_DETECTION
}

// Capture Mode
enum class CaptureMode {
    VIDEO, PHOTO
}

// Camera Settings
data class CameraSettings(
    val mode: CameraMode = CameraMode.ON,
    val zoom: Float = 1.0f,
    val exposureValue: Float = 0.0f,
    val mosaicEnabled: Boolean = false,
    val privacyFilterType: PrivacyFilterType = PrivacyFilterType.MOSAIC,
    val detectionMode: DetectionMode = DetectionMode.FACE_ONLY,
    val mosaicIntensity: Float = 20.0f,
    val mosaicCoverage: Float = 0.5f,
    val staticImage: Bitmap? = null
) {
    companion object {
        const val MIN_ZOOM = 1.0f
        const val MAX_ZOOM = 5.0f
        const val MIN_EV = -2.0f
        const val MAX_EV = 2.0f
        const val MIN_MOSAIC_INTENSITY = 5.0f
        const val MAX_MOSAIC_INTENSITY = 100.0f
        const val MIN_MOSAIC_COVERAGE = 0.0f
        const val MAX_MOSAIC_COVERAGE = 1.0f
    }
}

// PiP Settings
data class PiPSettings(
    val shape: PiPShape = PiPShape.RECTANGLE,
    val position: Offset = Offset(280f, 500f),
    val size: Float = 120f
) {
    companion object {
        const val MIN_SIZE = 80f
        const val MAX_SIZE = 200f
    }
}

// App State Manager
class AppStateManager {

    // Camera settings
    private val _frontCamera = MutableStateFlow(CameraSettings())
    val frontCamera: StateFlow<CameraSettings> = _frontCamera.asStateFlow()

    private val _backCamera = MutableStateFlow(CameraSettings())
    val backCamera: StateFlow<CameraSettings> = _backCamera.asStateFlow()

    // PiP settings
    private val _pipSettings = MutableStateFlow(PiPSettings())
    val pipSettings: StateFlow<PiPSettings> = _pipSettings.asStateFlow()

    // Which camera is main (full screen)
    private val _mainCameraIsBack = MutableStateFlow(true)
    val mainCameraIsBack: StateFlow<Boolean> = _mainCameraIsBack.asStateFlow()

    // Capture mode
    private val _captureMode = MutableStateFlow(CaptureMode.VIDEO)
    val captureMode: StateFlow<CaptureMode> = _captureMode.asStateFlow()

    // Recording state
    private val _isRecording = MutableStateFlow(false)
    val isRecording: StateFlow<Boolean> = _isRecording.asStateFlow()

    private val _recordingDuration = MutableStateFlow(0.0)
    val recordingDuration: StateFlow<Double> = _recordingDuration.asStateFlow()

    // Ad state - tracks if user needs to watch ad BEFORE next recording
    private val _needsToWatchAd = MutableStateFlow(false)
    val needsToWatchAd: StateFlow<Boolean> = _needsToWatchAd.asStateFlow()

    // Tracks if free recording has been used (requires ad for next recording)
    private var freeRecordingUsed = false

    // Pro state
    private val _isPro = MutableStateFlow(false)
    val isPro: StateFlow<Boolean> = _isPro.asStateFlow()

    // Recording limit for free version (30 seconds)
    val freeRecordingLimit = 30.0

    // Update methods
    fun updateFrontCamera(settings: CameraSettings) {
        _frontCamera.value = settings
    }

    fun updateBackCamera(settings: CameraSettings) {
        _backCamera.value = settings
    }

    fun updatePiPSettings(settings: PiPSettings) {
        _pipSettings.value = settings
    }

    fun toggleMainCamera() {
        _mainCameraIsBack.value = !_mainCameraIsBack.value
    }

    fun setCaptureMode(mode: CaptureMode) {
        _captureMode.value = mode
    }

    fun setRecording(recording: Boolean) {
        _isRecording.value = recording
        if (!recording) {
            _recordingDuration.value = 0.0
        }
    }

    fun updateRecordingDuration(duration: Double) {
        _recordingDuration.value = duration
    }

    fun setIsPro(isPro: Boolean) {
        _isPro.value = isPro
    }

    fun setNeedsToWatchAd(needs: Boolean) {
        _needsToWatchAd.value = needs
    }

    /**
     * Called when user attempts to start recording.
     * Returns true if recording can proceed, false if ad is required.
     */
    fun canStartRecording(): Boolean {
        if (_isPro.value) return true
        if (!freeRecordingUsed) return true
        // Free user who has already used free recording needs to watch ad
        _needsToWatchAd.value = true
        return false
    }

    fun onRecordingFinished() {
        // Mark that free recording has been used (don't show modal immediately)
        if (!_isPro.value) {
            freeRecordingUsed = true
        }
    }

    fun onPhotoTaken() {
        if (!_isPro.value) {
            // 19% chance to show ad
            if ((1..100).random() <= 19) {
                _needsToWatchAd.value = true
            }
        }
    }

    fun onAdWatched() {
        _needsToWatchAd.value = false
        freeRecordingUsed = false  // Allow next recording after watching ad
    }
}
