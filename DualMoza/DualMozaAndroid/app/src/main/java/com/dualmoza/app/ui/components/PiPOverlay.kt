package com.dualmoza.app.ui.components

import android.graphics.Bitmap
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import com.dualmoza.app.data.PiPShape
import kotlin.math.roundToInt

@Composable
fun PiPOverlay(
    bitmap: Bitmap,
    shape: PiPShape,
    position: Offset,
    size: Float,
    onPositionChange: (Offset) -> Unit,
    modifier: Modifier = Modifier
) {
    val density = LocalDensity.current
    var offsetX by remember { mutableFloatStateOf(position.x) }
    var offsetY by remember { mutableFloatStateOf(position.y) }

    val sizeDp = with(density) { size.toDp() }
    val height = if (shape == PiPShape.CIRCLE) sizeDp else sizeDp * 1.3f

    val clipShape = when (shape) {
        PiPShape.CIRCLE -> CircleShape
        PiPShape.RECTANGLE -> RoundedCornerShape(12.dp)
    }

    Box(
        modifier = modifier
            .offset { IntOffset(offsetX.roundToInt(), offsetY.roundToInt()) }
            .size(width = sizeDp, height = height)
            .clip(clipShape)
            .border(3.dp, Color.White, clipShape)
            .pointerInput(Unit) {
                detectDragGestures { change, dragAmount ->
                    change.consume()
                    offsetX += dragAmount.x
                    offsetY += dragAmount.y
                    onPositionChange(Offset(offsetX, offsetY))
                }
            }
    ) {
        Image(
            bitmap = bitmap.asImageBitmap(),
            contentDescription = "PiP Preview",
            modifier = Modifier.fillMaxSize(),
            contentScale = ContentScale.Crop
        )
    }
}
