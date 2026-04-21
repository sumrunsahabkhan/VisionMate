package com.example.visionmate

import android.content.Context
import android.media.MediaActionSound
import android.os.Vibrator
import android.os.VibrationEffect
import android.os.Build
import android.util.Log
import androidx.camera.core.*
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions

enum class CameraMode { COLOR, OBJECT, OCR }

class SmartCameraManager(
    private val context: Context,
    private val lifecycleOwner: LifecycleOwner,
    private val onFeedback: (String) -> Unit,
    private val onColorResult: (Map<String, Any>) -> Unit
) {
    private var cameraProvider: ProcessCameraProvider? = null
    private var camera: Camera? = null
    private var currentMode: CameraMode = CameraMode.COLOR
    private var lensFacing: Int = CameraSelector.LENS_FACING_BACK
    private val cameraExecutor: ExecutorService = Executors.newSingleThreadExecutor()

    private var lastProcessedTime = 0L
    private var isAnalyzing = false
    private var lastPreviewView: PreviewView? = null

    private val shutterSound = MediaActionSound()
    private val colorProcessor = ColorProcessor(context)
    private var pendingCaptureResult: MethodChannel.Result? = null

    private var isFlashOn = false
    private var lastBlurTime = 0L
    private var lastGuidanceTime = 0L
    private var lastOcrGuidanceTime = 0L

    // ML Kit Text Recognizer for real-time guidance
    private val textRecognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)

    private val sensorHelper = SensorHelper(context) { event ->
        if (isAnalyzing || pendingCaptureResult != null) return@SensorHelper
        when (event) {
            "LIGHT_LOW" -> {
                if (lensFacing == CameraSelector.LENS_FACING_BACK && !isFlashOn) {
                    isFlashOn = true
                    enableFlash(true)
                }
            }
            "LIGHT_OK" -> {
                if (isFlashOn) {
                    isFlashOn = false
                    enableFlash(false)
                }
            }
            "SHAKE" -> {
                onFeedback("Please hold steady.")
            }
        }
    }

    private val blurDetector = BlurDetector()

    fun startCamera(mode: CameraMode, previewView: PreviewView? = null) {
        currentMode = mode
        isAnalyzing = false
        lastGuidanceTime = 0L
        lastOcrGuidanceTime = System.currentTimeMillis() // Initialize to prevent immediate "No text" guidance
        shutterSound.load(MediaActionSound.SHUTTER_CLICK)
        if (previewView != null) lastPreviewView = previewView

        val cameraProviderFuture = ProcessCameraProvider.getInstance(context)
        cameraProviderFuture.addListener({
            try {
                cameraProvider = cameraProviderFuture.get()
                bindCameraUseCases(lastPreviewView)
                sensorHelper.start()
            } catch (e: Exception) {
                Log.e("SmartCameraManager", "Start error: ${e.message}")
            }
        }, ContextCompat.getMainExecutor(context))
    }

    private fun bindCameraUseCases(previewView: PreviewView?) {
        val cameraProvider = cameraProvider ?: return
        val cameraSelector = CameraSelector.Builder().requireLensFacing(lensFacing).build()
        val preview = Preview.Builder().build().also { it.setSurfaceProvider(previewView?.surfaceProvider) }
        
        val imageAnalysis = ImageAnalysis.Builder()
            .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
            .build()

        imageAnalysis.setAnalyzer(cameraExecutor, object : ImageAnalysis.Analyzer {
            @ExperimentalGetImage
            override fun analyze(imageProxy: ImageProxy) {
                val now = System.currentTimeMillis()

                if (pendingCaptureResult != null && !isAnalyzing) {
                    isAnalyzing = true
                    processCapture(imageProxy)
                    return
                }

                if (isAnalyzing || pendingCaptureResult != null || now - lastProcessedTime < 1000) {
                    imageProxy.close()
                    return
                }
                lastProcessedTime = now

                // Blur Detection logic
                val isBlurry = blurDetector.isBlurry(imageProxy)
                if (isBlurry) {
                    if (now - lastBlurTime > 7000) { 
                        lastBlurTime = now
                        onFeedback("Image is blurry. Please hold steady.") 
                    }
                    imageProxy.close()
                    return
                }

                // Real-time Text Detection Guidance
                if (currentMode == CameraMode.OCR && now - lastOcrGuidanceTime > 5000) {
                    val mediaImage = imageProxy.image
                    if (mediaImage != null) {
                        val image = InputImage.fromMediaImage(mediaImage, imageProxy.imageInfo.rotationDegrees)
                        textRecognizer.process(image)
                            .addOnSuccessListener { visionText ->
                                val currentTime = System.currentTimeMillis()
                                if (visionText.text.isNotBlank()) {
                                    if (currentTime - lastOcrGuidanceTime > 8000) {
                                        lastOcrGuidanceTime = currentTime
                                        onFeedback("Text detected. Hold steady and double tap to capture.")
                                    }
                                } else {
                                    // If no text is detected for 12 seconds, inform the user
                                    if (currentTime - lastOcrGuidanceTime > 12000) {
                                        lastOcrGuidanceTime = currentTime
                                        onFeedback("No text found. Move camera slowly.")
                                    }
                                }
                            }
                            .addOnCompleteListener {
                                imageProxy.close()
                            }
                        return
                    }
                }

                imageProxy.close()
            }
        })

        try {
            cameraProvider.unbindAll()
            camera = cameraProvider.bindToLifecycle(lifecycleOwner, cameraSelector, preview, imageAnalysis)
        } catch (e: Exception) { 
            Log.e("SmartCameraManager", "Bind error", e) 
        }
    }

    private fun processCapture(imageProxy: ImageProxy) {
        val result = pendingCaptureResult
        pendingCaptureResult = null

        // Vibration feedback
        val vibrator = context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator.vibrate(VibrationEffect.createOneShot(100, VibrationEffect.DEFAULT_AMPLITUDE))
        } else {
            vibrator.vibrate(100)
        }

        shutterSound.play(MediaActionSound.SHUTTER_CLICK)

        if (isFlashOn) {
            isFlashOn = false
            ContextCompat.getMainExecutor(context).execute { enableFlash(false) }
        }
        sensorHelper.setEnabled(false)

        // Final blur check before processing
        if (blurDetector.isBlurry(imageProxy)) {
            onFeedback("Image was blurry. Hold steady and scan again.")
            imageProxy.close()
            isAnalyzing = false
            result?.success(mapOf("error" to "BLURRY"))
            return
        }

        if (currentMode == CameraMode.OCR) {
            processGenericCapture(imageProxy, result)
        } else {
            processColorCapture(imageProxy, result)
        }
    }

    private fun processGenericCapture(imageProxy: ImageProxy, result: MethodChannel.Result?) {
        try {
            val colorResult = colorProcessor.processFrame(imageProxy)
            val resultMap = mapOf("imagePath" to colorResult.imagePath)
            ContextCompat.getMainExecutor(context).execute { 
                result?.success(resultMap)
                isAnalyzing = false 
            }
        } catch (e: Exception) {
            ContextCompat.getMainExecutor(context).execute { 
                result?.error("ERROR", e.message, null)
                isAnalyzing = false 
            }
        } finally {
            imageProxy.close()
        }
    }

    private fun processColorCapture(imageProxy: ImageProxy, result: MethodChannel.Result?) {
        try {
            val colorResult = colorProcessor.processFrame(imageProxy)
            val resultMap = mapOf(
                "color" to colorResult.name, 
                "confidence" to colorResult.confidence, 
                "hex" to colorResult.hex, 
                "imagePath" to colorResult.imagePath
            )
            ContextCompat.getMainExecutor(context).execute { 
                result?.success(resultMap)
                isAnalyzing = false 
            }
        } catch (e: Exception) {
            ContextCompat.getMainExecutor(context).execute { 
                result?.error("ERROR", e.message, null)
                isAnalyzing = false 
            }
        } finally {
            imageProxy.close()
        }
    }

    fun captureAndProcess(result: MethodChannel.Result) {
        pendingCaptureResult = result
    }

    fun stopCamera() {
        sensorHelper.stop()
        if (isFlashOn) { isFlashOn = false; enableFlash(false) }
        cameraProvider?.unbindAll()
        isAnalyzing = false
        pendingCaptureResult = null
    }

    fun enableFlash(enable: Boolean) {
        if (lensFacing == CameraSelector.LENS_FACING_BACK) {
            camera?.cameraControl?.enableTorch(enable)
        }
    }

    fun switchCamera() {
        val wasFront = lensFacing == CameraSelector.LENS_FACING_FRONT
        lensFacing = if (wasFront) CameraSelector.LENS_FACING_BACK else CameraSelector.LENS_FACING_FRONT
        if (isFlashOn) { isFlashOn = false; enableFlash(false) }
        onFeedback("__CAMERA_SWITCHED__:${if (lensFacing == CameraSelector.LENS_FACING_BACK) "back" else "front"}")
        startCamera(currentMode, lastPreviewView)
    }
}
