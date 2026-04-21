package com.example.visionmate

import androidx.camera.core.ImageProxy

class PositioningHelper {
    /**
     * Analyzes the frame to provide centering guidance.
     * Uses a 3x3 grid comparison of luminance.
     */
    fun getPositionFeedback(image: ImageProxy): String? {
        val buffer = image.planes[0].buffer
        val width = image.width
        val height = image.height
        val rowStride = image.planes[0].rowStride

        var leftSum = 0L
        var rightSum = 0L
        var topSum = 0L
        var bottomSum = 0L

        // Sample pixels for performance (10% sampling)
        val step = 10 
        for (y in 0 until height step step) {
            for (x in 0 until width step step) {
                val pixel = buffer.get(y * rowStride + x).toInt() and 0xFF
                
                if (x < width / 3) leftSum += pixel
                else if (x > 2 * width / 3) rightSum += pixel
                
                if (y < height / 3) topSum += pixel
                else if (y > 2 * height / 3) bottomSum += pixel
            }
        }

        // Guide logic: If one side is significantly 'heavier' in brightness/contrast, 
        // it likely contains the object/text.
        val horizontalDiff = leftSum.toDouble() / (rightSum + 1)
        val verticalDiff = topSum.toDouble() / (bottomSum + 1)

        return when {
            horizontalDiff > 1.6 -> "Move slightly left."
            horizontalDiff < 0.6 -> "Move slightly right."
            verticalDiff > 1.6 -> "Move slightly up."
            verticalDiff < 0.6 -> "Move slightly down."
            else -> null // Centered
        }
    }
}
