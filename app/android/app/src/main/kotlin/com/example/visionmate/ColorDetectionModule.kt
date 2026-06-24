package com.example.visionmate

import android.graphics.Color
import android.graphics.ImageFormat
import androidx.camera.core.ImageProxy

class ColorDetectionModule(private val onResult: (String) -> Unit) {
    private val hsvColorMapper = HSVColorMapper()

    fun analyzeFrame(image: ImageProxy): String {
        if (image.format != ImageFormat.YUV_420_888) return ""

        val width = image.width
        val height = image.height
        
        val cropPercent = 0.40
        val startX = (width * (1 - cropPercent) / 2).toInt()
        val startY = (height * (1 - cropPercent) / 2).toInt()
        val endX = (width * (1 + cropPercent) / 2).toInt()
        val endY = (height * (1 + cropPercent) / 2).toInt()

        val yBuffer = image.planes[0].buffer
        val uBuffer = image.planes[1].buffer
        val vBuffer = image.planes[2].buffer

        val yRowStride = image.planes[0].rowStride
        val uvRowStride = image.planes[1].rowStride
        val uvPixelStride = image.planes[1].pixelStride

        val colorFrequency = mutableMapOf<String, Int>()
        var totalPixels = 0

        val step = 4 
        for (y in startY until endY step step) {
            for (x in startX until endX step step) {
                totalPixels++
                val yIndex = y * yRowStride + x
                val uvIndex = (y / 2) * uvRowStride + (x / 2) * uvPixelStride

                val yp = yBuffer.get(yIndex).toInt() and 0xFF
                val up = (uBuffer.get(uvIndex).toInt() and 0xFF) - 128
                val vp = (vBuffer.get(uvIndex).toInt() and 0xFF) - 128

                val r = (yp + 1.370705 * vp).toInt().coerceIn(0, 255)
                val g = (yp - 0.337633 * up - 0.698001 * vp).toInt().coerceIn(0, 255)
                val b = (yp + 1.732446 * up).toInt().coerceIn(0, 255)

                val hsv = FloatArray(3)
                Color.RGBToHSV(r, g, b, hsv)
                val colorName = hsvColorMapper.getColorName(hsv)
                colorFrequency[colorName] = colorFrequency.getOrDefault(colorName, 0) + 1
            }
        }

        if (colorFrequency.isEmpty()) return "could not identify clearly"

        val sorted = colorFrequency.entries.sortedByDescending { it.value }
        val first = sorted[0].key
        val second = if (sorted.size > 1) sorted[1].key else null

        // 🔥 SHADOW & FAMILY PROTECTION:
        // If second color is just a shadow of the first (e.g. Red vs Pink), ignore it.
        if (second != null) {
            val secondCount = colorFrequency[second] ?: 0
            val ratio = secondCount.toFloat() / totalPixels
            
            if (ratio > 0.15f) {
                val isSameFamily = isSameFamily(first, second)
                if (!isSameFamily) {
                    return "Major color is $first and second is $second"
                }
            }
        }

        return first
    }

    private fun isSameFamily(c1: String, c2: String): Boolean {
        val pinks = listOf("Baby Pink", "Pink", "Pale Pink", "Light Pink")
        val reds = listOf("Red", "Maroon", "Crimson")
        val greys = listOf("Grey", "Dark Grey", "Silver", "White")
        
        if (pinks.contains(c1) && pinks.contains(c2)) return true
        if (reds.contains(c1) && reds.contains(c2)) return true
        if (greys.contains(c1) && greys.contains(c2)) return true
        // Shadow Check: If one is Pink and other is Red (common in shadows)
        if ((pinks.contains(c1) && reds.contains(c2)) || (reds.contains(c1) && pinks.contains(c2))) return true
        
        return false
    }

    fun detectColor(image: ImageProxy) {
        val result = analyzeFrame(image)
        if (result.isNotEmpty()) onResult(result)
        image.close()
    }
}
