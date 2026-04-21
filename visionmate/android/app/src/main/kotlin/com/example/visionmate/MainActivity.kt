package com.example.visionmate

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Bundle
import android.view.View
import android.util.Log
import androidx.camera.core.CameraSelector
import androidx.camera.view.PreviewView
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import java.io.File
import android.provider.MediaStore
import java.util.Locale

class MainActivity : FlutterActivity() {

    private var voskService: VoskService? = null
    private var smartCameraManager: SmartCameraManager? = null
    private var activePreviewView: PreviewView? = null
    
    private val TAG = "VisionMateNative"
    private val VOSK_CHANNEL = "visionmate/vosk"
    private val CAMERA_CHANNEL = "visionmate/camera"
    private val COLOR_ENGINE_CHANNEL = "visionmate/color_engine"
    private val PDF_CHANNEL = "visionmate/pdf_service"
    private val CAMERA_PERMISSION_CODE = 101

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        if (smartCameraManager == null) {
            smartCameraManager = SmartCameraManager(
                this, 
                this,
                onFeedback = { message ->
                    runOnUiThread {
                        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CAMERA_CHANNEL)
                            .invokeMethod("onCameraFeedback", message)
                        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, COLOR_ENGINE_CHANNEL)
                            .invokeMethod("onCameraFeedback", message)
                    }
                },
                onColorResult = { _ -> }
            )
        }

        flutterEngine.platformViewsController.registry.registerViewFactory(
            "visionmate/camera_preview",
            object : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
                override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
                    return object : PlatformView {
                        private val previewView = PreviewView(context)
                        init { activePreviewView = previewView }
                        override fun getView(): View = previewView
                        override fun dispose() { activePreviewView = null }
                    }
                }
            }
        )

        if (voskService == null) {
            voskService = VoskService(this) { text, isFinal ->
                runOnUiThread {
                    val data = mapOf("text" to text, "isFinal" to isFinal)
                    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VOSK_CHANNEL).invokeMethod("onSpeech", data)
                }
            }
        }

        setupMethodChannels(flutterEngine)
    }

    private fun setupMethodChannels(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VOSK_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startListening" -> { voskService?.start(); result.success(null) }
                    "stopListening" -> { voskService?.stop(); result.success(null) }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CAMERA_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openOCR" -> handleCameraAction(CameraMode.OCR, result)
                    "openColor" -> handleCameraAction(CameraMode.COLOR, result)
                    "openObject" -> handleCameraAction(CameraMode.OBJECT, result)
                    "switchCamera" -> { smartCameraManager?.switchCamera(); result.success(null) }
                    "stopCamera" -> { smartCameraManager?.stopCamera(); result.success(null) }
                    "captureAndProcess" -> { smartCameraManager?.captureAndProcess(result) } // 🔥 FIXED
                    "isBackCamera" -> {
                        val isBack = MethodChannelHelper.isBackCamera(smartCameraManager)
                        result.success(isBack)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, COLOR_ENGINE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startCamera" -> handleCameraAction(CameraMode.COLOR, result)
                    "stopCamera" -> { smartCameraManager?.stopCamera(); result.success(null) }
                    "captureAndProcess" -> { smartCameraManager?.captureAndProcess(result) }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PDF_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "getDevicePdfs") {
                    val pdfs = getPdfsFromMediaStore()
                    result.success(pdfs)
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun getPdfsFromMediaStore(): List<Map<String, Any>> {
        val pdfList = mutableListOf<Map<String, Any>>()
        val projection = arrayOf(
            MediaStore.Files.FileColumns.DISPLAY_NAME,
            MediaStore.Files.FileColumns.DATA,
            MediaStore.Files.FileColumns.DATE_MODIFIED
        )
        val queryUri = MediaStore.Files.getContentUri("external")
        val selection = "${MediaStore.Files.FileColumns.DATA} LIKE ?"
        val selectionArgs = arrayOf("%.pdf")
        val sortOrder = "${MediaStore.Files.FileColumns.DATE_MODIFIED} DESC"

        try {
            contentResolver.query(queryUri, projection, selection, selectionArgs, sortOrder)?.use { cursor ->
                val nameColumn = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DISPLAY_NAME)
                val pathColumn = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DATA)
                val dateColumn = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DATE_MODIFIED)

                while (cursor.moveToNext()) {
                    val name = cursor.getString(nameColumn) ?: "Unknown"
                    val path = cursor.getString(pathColumn) ?: ""
                    val date = cursor.getLong(dateColumn) * 1000
                    if (path.isNotEmpty() && path.lowercase(Locale.ROOT).endsWith(".pdf")) {
                        if (File(path).exists()) {
                            pdfList.add(mapOf("name" to name, "path" to path, "lastModified" to date))
                        }
                    }
                }
            }
        } catch (e: Exception) { Log.e(TAG, "PDF Query Error: ${e.message}") }
        return pdfList
    }

    private fun handleCameraAction(mode: CameraMode, result: MethodChannel.Result) {
        if (checkCameraPermission()) {
            runOnUiThread { smartCameraManager?.startCamera(mode, activePreviewView) }
            result.success(true)
        } else {
            requestCameraPermission()
            result.error("PERMISSION_DENIED", "Camera permission is required", null)
        }
    }

    private fun checkCameraPermission() = ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED
    private fun requestCameraPermission() = ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.CAMERA), CAMERA_PERMISSION_CODE)
}

object MethodChannelHelper {
    fun isBackCamera(manager: SmartCameraManager?): Boolean {
        if (manager == null) return true
        return try {
            val field = manager.javaClass.getDeclaredField("lensFacing")
            field.isAccessible = true
            val value = field.get(manager) as Int
            value == CameraSelector.LENS_FACING_BACK
        } catch (e: Exception) { true }
    }
}
