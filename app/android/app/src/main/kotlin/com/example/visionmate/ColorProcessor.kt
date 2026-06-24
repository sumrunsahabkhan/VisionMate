package com.example.visionmate

import android.content.Context
import android.graphics.*
import androidx.camera.core.ImageProxy
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream

data class ColorResult(val name: String, val confidence: Int, val hex: String, val imagePath: String)

class ColorProcessor(private val context: Context) {
    private val mapper = HSVColorMapper()

    fun processFrame(image: ImageProxy): ColorResult {
        // 🔥 CRITICAL FIX: Improved YUV to Bitmap conversion to prevent Green Tint
        val bitmap = imageToBitmap(image)
        val rotatedBitmap = rotateBitmap(bitmap, image.imageInfo.rotationDegrees)
        
        val timestamp = System.currentTimeMillis()
        val file = File(context.cacheDir, "color_capture_$timestamp.jpg")
        context.cacheDir.listFiles()?.forEach { if (it.name.startsWith("color_capture_")) it.delete() }
        FileOutputStream(file).use { out -> rotatedBitmap.compress(Bitmap.CompressFormat.JPEG, 85, out) }

        val scaledBitmap = Bitmap.createScaledBitmap(rotatedBitmap, 100, 100, true)
        val width = scaledBitmap.width
        val height = scaledBitmap.height
        
        val cropPercent = 0.40
        val startX = (width * (1 - cropPercent) / 2).toInt()
        val startY = (height * (1 - cropPercent) / 2).toInt()
        val endX = (width * (1 + cropPercent) / 2).toInt()
        val endY = (height * (1 + cropPercent) / 2).toInt()

        val colorFrequency = mutableMapOf<String, Int>()
        var totalPixels = 0

        for (y in startY until endY) {
            for (x in startX until endX) {
                totalPixels++
                val pixel = scaledBitmap.getPixel(x, y)
                val hsv = FloatArray(3)
                Color.colorToHSV(pixel, hsv)
                val colorName = mapper.getColorName(hsv)
                colorFrequency[colorName] = colorFrequency.getOrDefault(colorName, 0) + 1
            }
        }

        val centerPixel = rotatedBitmap.getPixel(rotatedBitmap.width / 2, rotatedBitmap.height / 2)
        val hex = String.format("#%06X", 0xFFFFFF and centerPixel)

        if (colorFrequency.isEmpty()) return ColorResult("Unknown", 0, "#000000", file.absolutePath)

        val sorted = colorFrequency.entries.sortedByDescending { it.value }
        val first = sorted[0]
        val second = if (sorted.size > 1) sorted[1] else null

        if (second != null && (second.value.toFloat() / totalPixels) > 0.20f) {
            val combinedName = "Major color is ${first.key} and second is ${second.key}"
            val confidence = (((first.value + second.value).toFloat() / totalPixels) * 100).toInt()
            return ColorResult(combinedName, confidence, hex, file.absolutePath)
        }

        val confidence = ((first.value.toFloat() / totalPixels) * 100).toInt()
        return ColorResult(first.key, confidence, hex, file.absolutePath)
    }

    private fun imageToBitmap(image: ImageProxy): Bitmap {
        val yBuffer = image.planes[0].buffer
        val uBuffer = image.planes[1].buffer
        val vBuffer = image.planes[2].buffer

        val ySize = yBuffer.remaining()
        val uSize = uBuffer.remaining()
        val vSize = vBuffer.remaining()

        val nv21 = ByteArray(ySize + uSize + vSize)

        // Correct NV21 format: Y plane, then interleaved V and U
        yBuffer.get(nv21, 0, ySize)
        vBuffer.get(nv21, ySize, vSize)
        uBuffer.get(nv21, ySize + vSize, uSize)

        val yuvImage = YuvImage(nv21, ImageFormat.NV21, image.width, image.height, null)
        val out = ByteArrayOutputStream()
        yuvImage.compressToJpeg(Rect(0, 0, yuvImage.width, yuvImage.height), 100, out)
        val imageBytes = out.toByteArray()
        return BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.size)
    }

    private fun rotateBitmap(bitmap: Bitmap, degrees: Int): Bitmap {
        val matrix = Matrix()
        matrix.postRotate(degrees.toFloat())
        return Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
    }
}
