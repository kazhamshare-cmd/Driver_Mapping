package com.dualmoza.app.ui.screens

import android.content.res.Configuration
import android.graphics.Bitmap
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.dualmoza.app.R
import com.dualmoza.app.camera.FaceDetector
import com.dualmoza.app.data.CameraMode
import com.dualmoza.app.data.CaptureMode
import com.dualmoza.app.data.DetectionMode
import com.dualmoza.app.data.PiPShape
import com.dualmoza.app.data.PrivacyFilterType
import com.dualmoza.app.ui.components.BottomBar
import com.dualmoza.app.ui.components.PiPOverlay
import com.dualmoza.app.ui.components.RecordingIndicator
import com.dualmoza.app.ui.components.Sidebar
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CameraScreen(
    viewModel: CameraViewModel = hiltViewModel()
) {
    val context = LocalContext.current
    val configuration = LocalConfiguration.current
    val isLandscape = configuration.orientation == Configuration.ORIENTATION_LANDSCAPE

    val captureMode by viewModel.captureMode.collectAsState()
    val isRecording by viewModel.isRecording.collectAsState()
    val recordingDuration by viewModel.recordingDuration.collectAsState()
    val isPro by viewModel.isPro.collectAsState()
    val needsToWatchAd by viewModel.needsToWatchAd.collectAsState()

    // Camera preview bitmaps
    val frontPreview by viewModel.frontCameraPreview.collectAsState()
    val backPreview by viewModel.backCameraPreview.collectAsState()

    // Privacy filter settings
    val mosaicEnabled by viewModel.mosaicEnabled.collectAsState()
    val privacyFilterType by viewModel.privacyFilterType.collectAsState()
    val detectionMode by viewModel.detectionMode.collectAsState()
    val mosaicIntensity by viewModel.mosaicIntensity.collectAsState()
    val mosaicMode by viewModel.mosaicMode.collectAsState()
    val mosaicCoverage by viewModel.mosaicCoverage.collectAsState()
    val showSettings by viewModel.showSettings.collectAsState()

    // Dual camera state
    val supportsDualCamera by viewModel.supportsDualCamera.collectAsState()
    val isDualModeActive by viewModel.isDualModeActive.collectAsState()
    val pipSettings by viewModel.pipSettings.collectAsState()
    val mainCameraIsBack by viewModel.mainCameraIsBack.collectAsState()
    val frontCameraSettings by viewModel.frontCamera.collectAsState()
    val backCameraSettings by viewModel.backCamera.collectAsState()

    // Zoom state
    val currentZoom by viewModel.currentZoom.collectAsState()
    val maxZoom by viewModel.maxZoom.collectAsState()

    // Capture events
    val captureEvent by viewModel.captureEvent.collectAsState()
    val snackbarHostState = remember { SnackbarHostState() }

    // Initialize camera
    LaunchedEffect(Unit) {
        viewModel.initializeCamera(context)
    }

    // String resources for snackbar
    val photoSavedMessage = stringResource(R.string.photo_saved)
    val videoSavedMessage = stringResource(R.string.video_saved)
    val saveFailedMessage = stringResource(R.string.save_failed)

    // Show snackbar on capture events
    LaunchedEffect(captureEvent) {
        captureEvent?.let { event ->
            val message = when (event) {
                is CameraViewModel.CaptureEvent.PhotoSaved -> photoSavedMessage
                is CameraViewModel.CaptureEvent.VideoSaved -> videoSavedMessage
                is CameraViewModel.CaptureEvent.CaptureFailed -> saveFailedMessage
            }
            snackbarHostState.showSnackbar(message, duration = SnackbarDuration.Short)
            viewModel.clearCaptureEvent()
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
    ) {
        // メインカメラがオフの場合、セカンダリカメラを全画面表示（iOS同様）
        val isMainCameraOff = if (mainCameraIsBack) {
            backCameraSettings.mode == CameraMode.OFF
        } else {
            frontCameraSettings.mode == CameraMode.OFF
        }

        val isPiPEnabled = if (mainCameraIsBack) {
            frontCameraSettings.mode != CameraMode.OFF
        } else {
            backCameraSettings.mode != CameraMode.OFF
        }

        // メインプレビューの決定
        val mainPreview = if (isMainCameraOff) {
            // メインカメラがオフならセカンダリを全画面表示
            if (mainCameraIsBack) frontPreview else backPreview
        } else {
            // 通常モード
            if (mainCameraIsBack) backPreview else frontPreview
        }

        MainCameraPreview(
            bitmap = mainPreview,
            modifier = Modifier.fillMaxSize()
        )

        // PiP表示（メインカメラがオンで、セカンダリもオンの場合のみ）
        val shouldShowPiP = !isMainCameraOff && isPiPEnabled
        if (shouldShowPiP) {
            val pipPreview = if (mainCameraIsBack) frontPreview else backPreview
            if (pipPreview != null) {
                PiPOverlay(
                    bitmap = pipPreview,
                    shape = pipSettings.shape,
                    position = pipSettings.position,
                    size = pipSettings.size,
                    onPositionChange = { viewModel.updatePiPPosition(it) }
                )
            }
        }

        // Recording indicator
        if (isRecording) {
            RecordingIndicator(
                duration = recordingDuration,
                freeLimit = viewModel.freeRecordingLimit,
                isPro = isPro,
                modifier = Modifier
                    .align(if (isLandscape) Alignment.TopStart else Alignment.TopCenter)
                    .padding(
                        top = if (isLandscape) 20.dp else 60.dp,
                        start = if (isLandscape) 20.dp else 0.dp
                    )
            )
        }

        // UI Controls (hide during recording)
        if (!isRecording) {
            // Top bar - Pro badge
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(
                        horizontal = 20.dp,
                        vertical = if (isLandscape) 20.dp else 60.dp
                    ),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Button(
                    onClick = {
                        if (!isPro) {
                            viewModel.upgradeToPro(context)
                        }
                    },
                    colors = ButtonDefaults.buttonColors(
                        containerColor = if (isPro) Color.Yellow else Color.Blue,
                        contentColor = if (isPro) Color.Black else Color.White
                    ),
                    shape = RoundedCornerShape(8.dp),
                    contentPadding = PaddingValues(horizontal = 10.dp, vertical = 4.dp)
                ) {
                    Text(
                        text = "PRO",
                        style = MaterialTheme.typography.labelMedium
                    )
                }
                Spacer(modifier = Modifier.weight(1f))
            }

            if (isLandscape) {
                // Landscape mode: Sidebar at bottom-left, controls at right
                Sidebar(
                    onFlipCamera = { viewModel.switchCamera() },
                    onOpenSettings = { viewModel.showSettings() },
                    captureMode = captureMode,
                    onCaptureModeChange = { viewModel.setCaptureMode(it) },
                    mosaicEnabled = mosaicEnabled,
                    onToggleMosaic = { viewModel.toggleMosaic() },
                    isPiPEnabled = isPiPEnabled,
                    onTogglePiP = { viewModel.togglePiP() },
                    supportsDualCamera = supportsDualCamera,
                    isLandscape = true,
                    modifier = Modifier
                        .align(Alignment.BottomStart)
                        .padding(start = 16.dp, bottom = 16.dp)
                )

                // Zoom slider (left side, vertical)
                ZoomSliderVertical(
                    currentZoom = currentZoom,
                    maxZoom = if (maxZoom > 1.0f) maxZoom else 5.0f,
                    onZoomChange = { viewModel.setZoom(it) },
                    modifier = Modifier
                        .align(Alignment.CenterStart)
                        .padding(start = 16.dp)
                )

                // Capture controls at right side
                LandscapeCaptureControls(
                    captureMode = captureMode,
                    isRecording = isRecording,
                    onCapture = {
                        if (captureMode == CaptureMode.VIDEO) {
                            viewModel.toggleRecording()
                        } else {
                            viewModel.capturePhoto()
                        }
                    },
                    onOpenGallery = { viewModel.openGallery(context) },
                    modifier = Modifier
                        .align(Alignment.CenterEnd)
                        .padding(end = 24.dp)
                )
            } else {
                // Portrait mode: Original layout
                Sidebar(
                    onFlipCamera = { viewModel.switchCamera() },
                    onOpenSettings = { viewModel.showSettings() },
                    captureMode = captureMode,
                    onCaptureModeChange = { viewModel.setCaptureMode(it) },
                    mosaicEnabled = mosaicEnabled,
                    onToggleMosaic = { viewModel.toggleMosaic() },
                    isPiPEnabled = isPiPEnabled,
                    onTogglePiP = { viewModel.togglePiP() },
                    supportsDualCamera = supportsDualCamera,
                    isLandscape = false,
                    modifier = Modifier
                        .align(Alignment.CenterEnd)
                        .padding(end = 16.dp)
                )

                // Zoom slider (bottom, above capture button)
                ZoomSlider(
                    currentZoom = currentZoom,
                    maxZoom = if (maxZoom > 1.0f) maxZoom else 5.0f,
                    onZoomChange = { viewModel.setZoom(it) },
                    modifier = Modifier
                        .align(Alignment.BottomCenter)
                        .padding(bottom = 140.dp)
                        .padding(horizontal = 40.dp)
                )

                // Bottom bar
                BottomBar(
                    captureMode = captureMode,
                    isRecording = isRecording,
                    onCapture = {
                        if (captureMode == CaptureMode.VIDEO) {
                            viewModel.toggleRecording()
                        } else {
                            viewModel.capturePhoto()
                        }
                    },
                    onOpenGallery = { viewModel.openGallery(context) },
                    modifier = Modifier
                        .align(Alignment.BottomCenter)
                        .padding(bottom = 40.dp)
                )
            }
        } else {
            // Stop button during recording
            Box(
                modifier = Modifier
                    .align(if (isLandscape) Alignment.CenterEnd else Alignment.BottomCenter)
                    .padding(
                        bottom = if (isLandscape) 0.dp else 40.dp,
                        end = if (isLandscape) 24.dp else 0.dp
                    )
            ) {
                IconButton(
                    onClick = { viewModel.toggleRecording() },
                    modifier = Modifier
                        .size(80.dp)
                        .clip(CircleShape)
                        .background(Color.White.copy(alpha = 0.2f))
                ) {
                    Box(
                        modifier = Modifier
                            .size(36.dp)
                            .clip(RoundedCornerShape(8.dp))
                            .background(Color.Red)
                    )
                }
            }
        }

        // Ad overlay
        if (needsToWatchAd && !isPro) {
            AdRequiredOverlay(
                onWatchAd = { viewModel.watchAd(context) },
                onUpgradeToPro = { viewModel.upgradeToPro(context) }
            )
        }

        // Snackbar for capture feedback
        SnackbarHost(
            hostState = snackbarHostState,
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(bottom = 140.dp)
        ) { snackbarData ->
            Snackbar(
                snackbarData = snackbarData,
                containerColor = Color(0xFF4CAF50),
                contentColor = Color.White
            )
        }
    }

    // Settings Bottom Sheet
    if (showSettings) {
        ModalBottomSheet(
            onDismissRequest = { viewModel.hideSettings() },
            containerColor = Color(0xFF1A1A1A)
        ) {
            SettingsContent(
                mosaicEnabled = mosaicEnabled,
                privacyFilterType = privacyFilterType,
                detectionMode = detectionMode,
                mosaicIntensity = mosaicIntensity,
                mosaicCoverage = mosaicCoverage,
                onToggleMosaic = { viewModel.toggleMosaic() },
                onFilterTypeChange = { viewModel.setPrivacyFilterType(it) },
                onDetectionModeChange = { viewModel.setDetectionMode(it) },
                onIntensityChange = { viewModel.setMosaicIntensity(it) },
                onCoverageChange = { viewModel.setMosaicCoverage(it) },
                onDismiss = { viewModel.hideSettings() }
            )
        }
    }
}

@Composable
private fun SettingsContent(
    mosaicEnabled: Boolean,
    privacyFilterType: PrivacyFilterType,
    detectionMode: DetectionMode,
    mosaicIntensity: Int,
    mosaicCoverage: Float,
    onToggleMosaic: () -> Unit,
    onFilterTypeChange: (PrivacyFilterType) -> Unit,
    onDetectionModeChange: (DetectionMode) -> Unit,
    onIntensityChange: (Int) -> Unit,
    onCoverageChange: (Float) -> Unit,
    onDismiss: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 24.dp)
            .padding(bottom = 40.dp)
    ) {
        Text(
            text = stringResource(R.string.settings),
            style = MaterialTheme.typography.headlineSmall,
            color = Color.White,
            modifier = Modifier.padding(bottom = 24.dp)
        )

        // Privacy Filter ON/OFF
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 8.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(stringResource(R.string.privacy_filter), color = Color.White)
            Switch(
                checked = mosaicEnabled,
                onCheckedChange = { onToggleMosaic() },
                colors = SwitchDefaults.colors(
                    checkedThumbColor = Color.White,
                    checkedTrackColor = Color(0xFF4CAF50)
                )
            )
        }

        // Filter Type Selection (only show when enabled)
        if (mosaicEnabled) {
            Spacer(modifier = Modifier.height(8.dp))

            Text(
                text = stringResource(R.string.filter_type),
                color = Color.White,
                style = MaterialTheme.typography.titleMedium,
                modifier = Modifier.padding(vertical = 8.dp)
            )

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                FilterTypeButton(
                    text = stringResource(R.string.filter_mosaic),
                    selected = privacyFilterType == PrivacyFilterType.MOSAIC,
                    onClick = { onFilterTypeChange(PrivacyFilterType.MOSAIC) },
                    modifier = Modifier.weight(1f)
                )
                FilterTypeButton(
                    text = stringResource(R.string.filter_blur),
                    selected = privacyFilterType == PrivacyFilterType.BLUR,
                    onClick = { onFilterTypeChange(PrivacyFilterType.BLUR) },
                    modifier = Modifier.weight(1f)
                )
            }

            Spacer(modifier = Modifier.height(16.dp))

            // Detection Mode Selection
            Text(
                text = stringResource(R.string.detection_mode),
                color = Color.White,
                style = MaterialTheme.typography.titleMedium,
                modifier = Modifier.padding(vertical = 8.dp)
            )

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                FilterTypeButton(
                    text = stringResource(R.string.face_only),
                    selected = detectionMode == DetectionMode.FACE_ONLY,
                    onClick = { onDetectionModeChange(DetectionMode.FACE_ONLY) },
                    modifier = Modifier.weight(1f)
                )
                FilterTypeButton(
                    text = stringResource(R.string.person_detection),
                    selected = detectionMode == DetectionMode.PERSON_DETECTION,
                    onClick = { onDetectionModeChange(DetectionMode.PERSON_DETECTION) },
                    modifier = Modifier.weight(1f)
                )
            }

            if (detectionMode == DetectionMode.PERSON_DETECTION) {
                Text(
                    text = stringResource(R.string.person_detection_note),
                    color = Color.Gray,
                    style = MaterialTheme.typography.bodySmall,
                    modifier = Modifier.padding(top = 4.dp)
                )
            }
        }

        Divider(color = Color.Gray.copy(alpha = 0.3f), modifier = Modifier.padding(vertical = 12.dp))

        // Coverage (range)
        Text(
            text = stringResource(R.string.filter_coverage),
            color = Color.White,
            style = MaterialTheme.typography.titleMedium,
            modifier = Modifier.padding(vertical = 8.dp)
        )

        Slider(
            value = mosaicCoverage,
            onValueChange = { onCoverageChange(it) },
            valueRange = 0f..1f,
            colors = SliderDefaults.colors(
                thumbColor = Color(0xFF4CAF50),
                activeTrackColor = Color(0xFF4CAF50)
            )
        )

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Text(stringResource(R.string.eyes_only), color = Color.Gray, style = MaterialTheme.typography.bodySmall)
            Text(stringResource(R.string.full_face), color = Color.Gray, style = MaterialTheme.typography.bodySmall)
        }

        Spacer(modifier = Modifier.height(16.dp))

        // Intensity
        Text(
            text = stringResource(R.string.filter_intensity_value, mosaicIntensity),
            color = Color.White,
            style = MaterialTheme.typography.titleMedium,
            modifier = Modifier.padding(vertical = 8.dp)
        )

        Slider(
            value = mosaicIntensity.toFloat(),
            onValueChange = { onIntensityChange(it.toInt()) },
            valueRange = 5f..30f,
            steps = 24,
            colors = SliderDefaults.colors(
                thumbColor = Color(0xFF4CAF50),
                activeTrackColor = Color(0xFF4CAF50)
            )
        )

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Text(stringResource(R.string.weak), color = Color.Gray, style = MaterialTheme.typography.bodySmall)
            Text(stringResource(R.string.strong), color = Color.Gray, style = MaterialTheme.typography.bodySmall)
        }

        Spacer(modifier = Modifier.height(24.dp))

        Button(
            onClick = onDismiss,
            modifier = Modifier.fillMaxWidth(),
            colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF4CAF50))
        ) {
            Text(stringResource(R.string.close))
        }
    }
}

@Composable
private fun FilterTypeButton(
    text: String,
    selected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Surface(
        modifier = modifier
            .clip(RoundedCornerShape(8.dp))
            .clickable { onClick() },
        color = if (selected) Color(0xFF4CAF50) else Color.Gray.copy(alpha = 0.3f),
        shape = RoundedCornerShape(8.dp)
    ) {
        Text(
            text = text,
            color = Color.White,
            modifier = Modifier.padding(vertical = 12.dp, horizontal = 16.dp),
            style = MaterialTheme.typography.bodyMedium,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            textAlign = TextAlign.Center
        )
    }
}

@Composable
private fun ModeButton(
    text: String,
    selected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Surface(
        modifier = modifier
            .clip(RoundedCornerShape(8.dp))
            .clickable { onClick() },
        color = if (selected) Color(0xFF4CAF50) else Color.Gray.copy(alpha = 0.3f),
        shape = RoundedCornerShape(8.dp)
    ) {
        Text(
            text = text,
            color = Color.White,
            modifier = Modifier.padding(vertical = 12.dp, horizontal = 16.dp),
            style = MaterialTheme.typography.bodyMedium,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            textAlign = TextAlign.Center
        )
    }
}

@Composable
private fun MainCameraPreview(
    bitmap: Bitmap?,
    modifier: Modifier = Modifier
) {
    if (bitmap != null) {
        Image(
            bitmap = bitmap.asImageBitmap(),
            contentDescription = "Camera Preview",
            modifier = modifier,
            contentScale = ContentScale.Crop
        )
    } else {
        Box(
            modifier = modifier.background(Color.Black),
            contentAlignment = Alignment.Center
        ) {
            CircularProgressIndicator(color = Color.White)
        }
    }
}

@Composable
private fun ZoomSlider(
    currentZoom: Float,
    maxZoom: Float,
    onZoomChange: (Float) -> Unit,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(24.dp))
            .background(Color.Black.copy(alpha = 0.5f))
            .padding(horizontal = 16.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        // Wide label (1x)
        Text(
            text = "1x",
            color = Color.White,
            style = MaterialTheme.typography.labelMedium
        )

        // Slider
        Slider(
            value = currentZoom,
            onValueChange = onZoomChange,
            valueRange = 1f..maxZoom,
            modifier = Modifier.weight(1f),
            colors = SliderDefaults.colors(
                thumbColor = Color.White,
                activeTrackColor = Color(0xFF4CAF50),
                inactiveTrackColor = Color.White.copy(alpha = 0.3f)
            )
        )

        // Zoom level indicator
        Text(
            text = String.format("%.1fx", currentZoom),
            color = Color.White,
            style = MaterialTheme.typography.labelMedium,
            modifier = Modifier.width(40.dp)
        )
    }
}

@Composable
private fun ZoomSliderVertical(
    currentZoom: Float,
    maxZoom: Float,
    onZoomChange: (Float) -> Unit,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .height(200.dp)
            .clip(RoundedCornerShape(24.dp))
            .background(Color.Black.copy(alpha = 0.5f))
            .padding(horizontal = 8.dp, vertical = 16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        // Zoom level indicator at top
        Text(
            text = String.format("%.1fx", currentZoom),
            color = Color.White,
            style = MaterialTheme.typography.labelMedium
        )

        // Vertical Slider
        Slider(
            value = currentZoom,
            onValueChange = onZoomChange,
            valueRange = 1f..maxZoom,
            modifier = Modifier
                .weight(1f)
                .width(40.dp),
            colors = SliderDefaults.colors(
                thumbColor = Color.White,
                activeTrackColor = Color(0xFF4CAF50),
                inactiveTrackColor = Color.White.copy(alpha = 0.3f)
            )
        )

        // Wide label (1x) at bottom
        Text(
            text = "1x",
            color = Color.White,
            style = MaterialTheme.typography.labelMedium
        )
    }
}

@Composable
private fun LandscapeCaptureControls(
    captureMode: CaptureMode,
    isRecording: Boolean,
    onCapture: () -> Unit,
    onOpenGallery: () -> Unit,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier,
        verticalArrangement = Arrangement.spacedBy(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        // Gallery button
        Box(
            modifier = Modifier
                .size(50.dp)
                .clip(RoundedCornerShape(8.dp))
                .background(Color.White.copy(alpha = 0.2f))
                .clickable { onOpenGallery() },
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = Icons.Filled.PhotoLibrary,
                contentDescription = "Gallery",
                tint = Color.White,
                modifier = Modifier.size(24.dp)
            )
        }

        // Capture button
        LandscapeCaptureButton(
            captureMode = captureMode,
            isRecording = isRecording,
            onClick = onCapture
        )
    }
}

@Composable
private fun LandscapeCaptureButton(
    captureMode: CaptureMode,
    isRecording: Boolean,
    onClick: () -> Unit
) {
    Box(
        modifier = Modifier
            .size(80.dp)
            .clip(CircleShape)
            .background(Color.White.copy(alpha = 0.1f))
            .clickable { onClick() },
        contentAlignment = Alignment.Center
    ) {
        Box(
            modifier = Modifier
                .size(72.dp)
                .clip(CircleShape)
                .background(Color.Transparent)
                .padding(4.dp),
            contentAlignment = Alignment.Center
        ) {
            // Outer ring
            Box(
                modifier = Modifier
                    .size(72.dp)
                    .clip(CircleShape)
                    .background(Color.Transparent)
            )
            when {
                isRecording -> {
                    // Stop button (square)
                    Box(
                        modifier = Modifier
                            .size(36.dp)
                            .clip(RoundedCornerShape(8.dp))
                            .background(Color.Red)
                    )
                }
                captureMode == CaptureMode.VIDEO -> {
                    // Video record button (red circle)
                    Box(
                        modifier = Modifier
                            .size(60.dp)
                            .clip(CircleShape)
                            .background(Color.Red)
                    )
                }
                else -> {
                    // Photo button (white circle)
                    Box(
                        modifier = Modifier
                            .size(60.dp)
                            .clip(CircleShape)
                            .background(Color.White)
                    )
                }
            }
        }
    }
}

@Composable
private fun AdRequiredOverlay(
    onWatchAd: () -> Unit,
    onUpgradeToPro: () -> Unit
) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black.copy(alpha = 0.8f)),
        contentAlignment = Alignment.Center
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(20.dp)
        ) {
            Icon(
                imageVector = Icons.Filled.PlayCircle,
                contentDescription = null,
                modifier = Modifier.size(60.dp),
                tint = Color.White
            )

            Text(
                text = stringResource(R.string.ad_required),
                style = MaterialTheme.typography.titleMedium,
                color = Color.White
            )

            Button(
                onClick = onWatchAd,
                colors = ButtonDefaults.buttonColors(containerColor = Color.White)
            ) {
                Icon(
                    imageVector = Icons.Filled.PlayArrow,
                    contentDescription = null,
                    tint = Color.Black
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text(stringResource(R.string.watch_ad), color = Color.Black)
            }

            TextButton(onClick = onUpgradeToPro) {
                Text(stringResource(R.string.pro_no_ads), color = Color.Blue)
            }
        }
    }
}
