package com.dabindev.momenta.momenta

import android.content.Intent
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity : FlutterActivity(), RecognitionListener {
    private val speechChannel = "com.dabindev.momenta/speech"
    private var pendingSpeechResult: MethodChannel.Result? = null
    private var speechRecognizer: SpeechRecognizer? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, speechChannel).setMethodCallHandler { call, result ->
            when (call.method) {
                "startSpeechToText" -> startSpeechToText(result)
                "stopSpeechToText" -> stopSpeechToText(result)
                "cancelSpeechToText" -> cancelSpeechToText(result)
                else -> result.notImplemented()
            }
        }
    }

    private fun startSpeechToText(result: MethodChannel.Result) {
        if (pendingSpeechResult != null) {
            result.error("busy", "Speech recognition is busy", null)
            return
        }

        if (!SpeechRecognizer.isRecognitionAvailable(this)) {
            result.error("unavailable", "Speech recognition service unavailable", null)
            return
        }

        if (speechRecognizer == null) {
            speechRecognizer = SpeechRecognizer.createSpeechRecognizer(this).apply {
                setRecognitionListener(this@MainActivity)
            }
        }

        pendingSpeechResult = result

        val localeTag = Locale.getDefault().toLanguageTag()
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, localeTag)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, localeTag)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, false)
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, 1200)
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS, 1200)
        }

        speechRecognizer?.startListening(intent)
    }

    private fun stopSpeechToText(result: MethodChannel.Result) {
        if (pendingSpeechResult == null) {
            result.success(null)
            return
        }

        speechRecognizer?.stopListening()
        result.success(null)
    }

    private fun cancelSpeechToText(result: MethodChannel.Result) {
        if (pendingSpeechResult == null) {
            result.success(null)
            return
        }

        speechRecognizer?.cancel()
        finishWithError("cancelled", "Speech recognition cancelled")
        result.success(null)
    }

    override fun onReadyForSpeech(params: Bundle?) = Unit

    override fun onBeginningOfSpeech() = Unit

    override fun onRmsChanged(rmsdB: Float) = Unit

    override fun onBufferReceived(buffer: ByteArray?) = Unit

    override fun onEndOfSpeech() = Unit

    override fun onPartialResults(partialResults: Bundle?) = Unit

    override fun onEvent(eventType: Int, params: Bundle?) = Unit

    override fun onResults(results: Bundle?) {
        val text = results
            ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
            ?.map { it.trim() }
            ?.firstOrNull { it.isNotEmpty() }

        if (text.isNullOrEmpty()) {
            finishWithError("no_match", "No speech recognized")
        } else {
            runOnUiThread {
                pendingSpeechResult?.success(text)
                pendingSpeechResult = null
            }
        }
    }

    override fun onError(error: Int) {
        if (pendingSpeechResult == null) {
            return
        }

        when (error) {
            SpeechRecognizer.ERROR_NO_MATCH,
            SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> finishWithError("no_match", "No speech recognized")
            SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> finishWithError("busy", "Speech recognition is busy")
            SpeechRecognizer.ERROR_CLIENT -> finishWithError("cancelled", "Speech recognition cancelled")
            else -> finishWithError("failed", "Speech recognition failed")
        }
    }

    override fun onDestroy() {
        speechRecognizer?.destroy()
        speechRecognizer = null
        pendingSpeechResult = null
        super.onDestroy()
    }

    private fun finishWithError(code: String, message: String) {
        runOnUiThread {
            pendingSpeechResult?.error(code, message, null)
            pendingSpeechResult = null
        }
    }
}
