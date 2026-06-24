package com.example.visionmate

import android.graphics.ImageFormat
import androidx.camera.core.ImageProxy
import java.nio.ByteBuffer
import kotlin.math.abs

class BlurDetector {

    /**
     * Improved blur detection.
     * Detects if the image is out of focus or moving too fast.
     */
    fun isBlurry(image: ImageProxy): Boolean {
        if (image.format != ImageFormat.YUV_420_888) return false

        val planes = image.planes
        val buffer = planes[0].buffer
        val width = image.width
        val height = image.height
        val rowStride = planes[0].rowStride

        // Check center area
        val centerBlur = calculateVariance(buffer, width / 2, height / 2, rowStride)
        
        // Threshold tuning:
        // High variance (>18) = Sharp, focus is good.
        // Low variance (<14) = Blurry or extremely dark.
        // We use 14.5 to be slightly more strict about focus.
        return centerBlur < 14.5
    }

    private fun calculateVariance(buffer: ByteBuffer, startX: Int, startY: Int, rowStride: Int): Double {
        val size = 100 // Larger sample area for better accuracy
        var mean = 0.0
        val pixels = IntArray(size * size)
        var count = 0

        val halfSize = size / 2
        for (y in (startY - halfSize) until (startY + halfSize)) {
            for (x in (startX - halfSize) until (startX + halfSize)) {
                val index = y * rowStride + x
                if (index >= 0 && index < buffer.capacity()) {
                    val pixel = buffer.get(index).toInt() and 0xFF
                    pixels[count++] = pixel
                    mean += pixel
                }
            }
        }
        
        if (count == 0) return 0.0
        mean /= count

        var variance = 0.0
        for (i in 0 until count) {
            variance += abs(pixels[i] - mean)
        }
        
        // Dark frame protection: If the image is very dark, variance is naturally low.
        // We don't want to report "Blurry" just because it's dark.
        if (mean < 25) return 20.0 // Return "Sharp" value to avoid dark-blur false positives

        return variance / count
    }
}
