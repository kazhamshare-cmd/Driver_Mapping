package com.dualmoza.app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.dualmoza.app.R
import com.dualmoza.app.data.CaptureMode

@Composable
fun Sidebar(
    onFlipCamera: () -> Unit,
    onOpenSettings: () -> Unit,
    captureMode: CaptureMode,
    onCaptureModeChange: (CaptureMode) -> Unit,
    mosaicEnabled: Boolean = true,
    onToggleMosaic: () -> Unit = {},
    isPiPEnabled: Boolean = true,
    onTogglePiP: () -> Unit = {},
    supportsDualCamera: Boolean = false,
    isLandscape: Boolean = false,
    modifier: Modifier = Modifier
) {
    val content: @Composable () -> Unit = {
        // Flip camera
        SidebarButton(
            icon = Icons.Filled.FlipCameraAndroid,
            label = stringResource(R.string.flip),
            onClick = onFlipCamera
        )

        // PiP toggle (デュアルカメラ対応機種のみ表示)
        if (supportsDualCamera) {
            SidebarButton(
                icon = if (isPiPEnabled) Icons.Filled.PictureInPicture else Icons.Filled.PictureInPictureAlt,
                label = stringResource(R.string.pip),
                isActive = isPiPEnabled,
                onClick = onTogglePiP
            )
        }

        // Mosaic toggle
        SidebarButton(
            icon = Icons.Filled.BlurOn,
            label = if (mosaicEnabled) stringResource(R.string.mosaic_on) else stringResource(R.string.mosaic_off),
            isActive = mosaicEnabled,
            onClick = onToggleMosaic
        )

        // Capture mode toggle
        SidebarButton(
            icon = if (captureMode == CaptureMode.VIDEO) Icons.Filled.Videocam else Icons.Filled.PhotoCamera,
            label = if (captureMode == CaptureMode.VIDEO) stringResource(R.string.video) else stringResource(R.string.photo),
            onClick = {
                onCaptureModeChange(
                    if (captureMode == CaptureMode.VIDEO) CaptureMode.PHOTO else CaptureMode.VIDEO
                )
            }
        )

        // Settings
        SidebarButton(
            icon = Icons.Filled.Settings,
            label = stringResource(R.string.settings),
            onClick = onOpenSettings
        )
    }

    if (isLandscape) {
        // Landscape: horizontal layout
        Row(
            modifier = modifier
                .clip(RoundedCornerShape(16.dp))
                .background(Color.Black.copy(alpha = 0.5f))
                .padding(12.dp),
            horizontalArrangement = Arrangement.spacedBy(16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            content()
        }
    } else {
        // Portrait: vertical layout
        Column(
            modifier = modifier
                .clip(RoundedCornerShape(16.dp))
                .background(Color.Black.copy(alpha = 0.5f))
                .padding(12.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            content()
        }
    }
}

@Composable
private fun SidebarButton(
    icon: ImageVector,
    label: String,
    isActive: Boolean = false,
    onClick: () -> Unit
) {
    Column(
        modifier = Modifier
            .clip(RoundedCornerShape(12.dp))
            .clickable { onClick() }
            .padding(8.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Box(
            modifier = Modifier
                .size(44.dp)
                .clip(CircleShape)
                .background(
                    if (isActive) Color(0xFF4CAF50).copy(alpha = 0.8f)
                    else Color.White.copy(alpha = 0.2f)
                ),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = icon,
                contentDescription = label,
                tint = Color.White,
                modifier = Modifier.size(24.dp)
            )
        }
        Text(
            text = label,
            color = if (isActive) Color(0xFF4CAF50) else Color.White,
            fontSize = 10.sp,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            textAlign = TextAlign.Center
        )
    }
}
