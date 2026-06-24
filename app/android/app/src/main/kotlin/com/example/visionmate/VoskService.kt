package com.example.visionmate

import android.content.Context
import android.util.Log
import org.json.JSONObject
import org.vosk.Model
import org.vosk.Recognizer
import org.vosk.android.RecognitionListener
import org.vosk.android.SpeechService
import java.io.File
import java.io.FileOutputStream

class VoskService(
    private val context: Context,
    private val onText: (String, Boolean) -> Unit
) : RecognitionListener {

    private var speechService: SpeechService? = null
    private var model: Model? = null
    private var recognizer: Recognizer? = null
    
    private var isModelLoaded = false
    private var isListening = false // 🔥 Added state tracking

    init {
        Thread {
            try {
                val modelDir = File(context.filesDir, "vosk-en")
                if (!modelDir.exists()) {
                    copyAssetFolder(context.assets, "models/vosk-en", modelDir.absolutePath)
                }
                model = Model(modelDir.absolutePath)
                recognizer = Recognizer(model, 16000.0f)
                isModelLoaded = true
                Log.d("VOSK", "Model loaded successfully")
            } catch (e: Exception) {
                Log.e("VOSK", "Init error", e)
            }
        }.start()
    }

    fun start() {
        if (!isModelLoaded) return
        
        try {
            isListening = true // 🔥 Set listening to true
            if (speechService == null) {
                speechService = SpeechService(recognizer, 16000.0f)
            }
            speechService?.startListening(this)
            Log.d("VOSK", "Started listening")
        } catch (e: Exception) {
            Log.e("VOSK", "Start error", e)
        }
    }

    fun stop() {
        isListening = false // 🔥 Set listening to false
        speechService?.stop()
        Log.d("VOSK", "Stopped listening")
    }

    private fun copyAssetFolder(assetManager: android.content.res.AssetManager,
                                fromAssetPath: String,
                                toPath: String) {
        val files = assetManager.list(fromAssetPath) ?: return
        File(toPath).mkdirs()
        for (file in files) {
            val assetFilePath = "$fromAssetPath/$file"
            val outFilePath = "$toPath/$file"
            val subFiles = assetManager.list(assetFilePath)
            if (subFiles != null && subFiles.isNotEmpty()) {
                copyAssetFolder(assetManager, assetFilePath, outFilePath)
            } else {
                assetManager.open(assetFilePath).use { input ->
                    FileOutputStream(File(outFilePath)).use { output ->
                        input.copyTo(output)
                    }
                }
            }
        }
    }

    override fun onPartialResult(hypothesis: String?) {
        if (!isListening) return // 🔥 Ignore if we are supposed to be stopped
        hypothesis?.let {
            try {
                val json = JSONObject(it)
                val partial = json.optString("partial", "")
                if (partial.isNotBlank()) onText(partial, false)
            } catch (e: Exception) {}
        }
    }

    override fun onResult(hypothesis: String?) {
        if (!isListening) return // 🔥 Ignore if we are supposed to be stopped
        hypothesis?.let {
            try {
                val json = JSONObject(it)
                val text = json.optString("text", "")
                if (text.isNotBlank()) onText(text, true)
            } catch (e: Exception) {}
        }
        
        // 🔥 Only auto-restart if we are still supposed to be listening
        if (isListening) {
            speechService?.startListening(this)
        }
    }

    override fun onFinalResult(hypothesis: String?) {}
    override fun onError(e: Exception?) { Log.e("VOSK", "Error", e) }
    override fun onTimeout() {}
}
