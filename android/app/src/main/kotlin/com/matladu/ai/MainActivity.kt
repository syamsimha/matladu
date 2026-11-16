package com.matladu.ai

import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import java.util.ArrayList
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val METHOD_CHANNEL = "com.matladu.ai/network_state"
    private val EVENT_CHANNEL = "com.matladu.ai/network_state_stream"
    private val TTS_SETTINGS_CHANNEL = "com.matladu.ai/tts_settings"
    private val SPEECH_RECOGNIZER_CHANNEL = "com.matladu.ai/speech_recognizer"

    private var connectivityManager: ConnectivityManager? = null
    private var networkCallback: ConnectivityManager.NetworkCallback? = null
    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var speechRecognizer: SpeechRecognizer? = null
    private var speechChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        connectivityManager = getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager

        // MethodChannel for one-shot check
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getNetworkState" -> {
                    result.success(checkNetworkState())
                }
                else -> result.notImplemented()
            }
        }

        // MethodChannel for Android TTS settings & voice data installation
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TTS_SETTINGS_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openTtsSettings" -> {
                    try {
                        val intent = Intent("com.android.settings.TTS_SETTINGS").apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        context.startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        try {
                            val intent = Intent(android.provider.Settings.ACTION_SETTINGS).apply {
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            context.startActivity(intent)
                            result.success(true)
                        } catch (e2: Exception) {
                            result.error("UNAVAILABLE", e2.message, null)
                        }
                    }
                }
                "openInstallTtsData" -> {
                    try {
                        val intent = Intent(android.speech.tts.TextToSpeech.Engine.ACTION_INSTALL_TTS_DATA).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        context.startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        try {
                            val intent = Intent("com.android.settings.TTS_SETTINGS").apply {
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            context.startActivity(intent)
                            result.success(true)
                        } catch (e2: Exception) {
                            result.error("UNAVAILABLE", e2.message, null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }

        // EventChannel for real-time network capability changes
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    registerNetworkCallback()
                    // Send initial state immediately
                    events?.success(checkNetworkState())
                }

                override fun onCancel(arguments: Any?) {
                    unregisterNetworkCallback()
                    eventSink = null
                }
            }
        )

        // MethodChannel for Android SpeechRecognizer (Google Speech Services)
        speechChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SPEECH_RECOGNIZER_CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "isAvailable" -> {
                        val avail = SpeechRecognizer.isRecognitionAvailable(this@MainActivity)
                        result.success(avail)
                    }
                    "startListening" -> {
                        val locale = call.argument<String>("locale") ?: "en-IN"
                        startSpeechRecognition(locale, result)
                    }
                    "stopListening" -> {
                        stopSpeechRecognition()
                        result.success(true)
                    }
                    "cancel" -> {
                        cancelSpeechRecognition()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    private fun startSpeechRecognition(locale: String, result: MethodChannel.Result) {
        mainHandler.post {
            try {
                if (!SpeechRecognizer.isRecognitionAvailable(this)) {
                    result.error("UNAVAILABLE", "Speech recognition service not available on device", null)
                    return@post
                }
                speechRecognizer?.destroy()
                speechRecognizer = SpeechRecognizer.createSpeechRecognizer(this).apply {
                    setRecognitionListener(object : RecognitionListener {
                        override fun onReadyForSpeech(params: Bundle?) {
                            speechChannel?.invokeMethod("onStateChanged", "listening")
                        }
                        override fun onBeginningOfSpeech() {
                            speechChannel?.invokeMethod("onStateChanged", "speaking")
                        }
                        override fun onRmsChanged(rmsdB: Float) {
                            speechChannel?.invokeMethod("onRmsChanged", rmsdB.toDouble())
                        }
                        override fun onBufferReceived(buffer: ByteArray?) {}
                        override fun onEndOfSpeech() {
                            speechChannel?.invokeMethod("onStateChanged", "transcribing")
                        }
                        override fun onError(error: Int) {
                            val msg = when (error) {
                                SpeechRecognizer.ERROR_AUDIO -> "Audio recording error. Please check microphone hardware."
                                SpeechRecognizer.ERROR_CLIENT -> "Android speech recognition client error. Please try again."
                                SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "Microphone permission required for speech recognition."
                                SpeechRecognizer.ERROR_NETWORK -> "Network connection error during cloud speech recognition. Please check internet connection."
                                SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "Network timeout during cloud speech recognition. Please check internet connection."
                                SpeechRecognizer.ERROR_NO_MATCH -> "No speech recognized. Please speak closer to the microphone."
                                SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "Speech recognition service is busy. Please try again."
                                SpeechRecognizer.ERROR_SERVER -> "Google speech recognition server error. Please try again."
                                SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "No speech detected. Please speak clearly into the microphone."
                                else -> "Speech recognition error ($error)"
                            }
                            speechChannel?.invokeMethod("onError", msg)
                        }
                        override fun onResults(results: Bundle?) {
                            val matches: ArrayList<String>? = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                            val confidences: FloatArray? = results?.getFloatArray(SpeechRecognizer.CONFIDENCE_SCORES)
                            val text = matches?.firstOrNull() ?: ""
                            val confidence = confidences?.firstOrNull()?.toDouble() ?: 0.95
                            speechChannel?.invokeMethod("onFinalResult", mapOf(
                                "text" to text,
                                "confidence" to confidence
                            ))
                        }
                        override fun onPartialResults(partialResults: Bundle?) {
                            val matches: ArrayList<String>? = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                            val text = matches?.firstOrNull() ?: ""
                            if (text.isNotEmpty()) {
                                speechChannel?.invokeMethod("onPartialResult", text)
                            }
                        }
                        override fun onEvent(eventType: Int, params: Bundle?) {}
                    })
                }

                val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE, locale)
                    putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                    putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
                }
                speechRecognizer?.startListening(intent)
                result.success(true)
            } catch (e: Exception) {
                result.error("ERROR", e.message, null)
            }
        }
    }

    private fun stopSpeechRecognition() {
        mainHandler.post {
            try {
                speechRecognizer?.stopListening()
            } catch (_: Exception) {}
        }
    }

    private fun cancelSpeechRecognition() {
        mainHandler.post {
            try {
                speechRecognizer?.cancel()
                speechRecognizer?.destroy()
                speechRecognizer = null
            } catch (_: Exception) {}
        }
    }

    private fun checkNetworkState(
        lostNetwork: Network? = null,
        freshNetwork: Network? = null,
        freshCapabilities: NetworkCapabilities? = null
    ): Map<String, Any> {
        val cm = connectivityManager ?: return mapOf(
            "isConnected" to false,
            "isValidated" to false,
            "isWifi" to false,
            "isCellular" to false,
            "type" to "none"
        )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val activeNetwork: Network? = freshNetwork ?: cm.activeNetwork
            if (activeNetwork == null || activeNetwork == lostNetwork) {
                return mapOf(
                    "isConnected" to false,
                    "isValidated" to false,
                    "isWifi" to false,
                    "isCellular" to false,
                    "type" to "none"
                )
            }

            val capabilities: NetworkCapabilities? = freshCapabilities ?: cm.getNetworkCapabilities(activeNetwork)

            if (capabilities != null) {
                val hasInternet = capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                val isValidated = capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
                val isWifi = capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)
                val isCellular = capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR)

                val type = when {
                    isWifi -> "wifi"
                    isCellular -> "cellular"
                    capabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> "ethernet"
                    else -> "other"
                }

                return mapOf(
                    "isConnected" to (hasInternet && isValidated),
                    "isValidated" to isValidated,
                    "isWifi" to isWifi,
                    "isCellular" to isCellular,
                    "type" to type
                )
            }
        } else {
            @Suppress("DEPRECATION")
            val networkInfo = cm.activeNetworkInfo
            @Suppress("DEPRECATION")
            val isConnected = networkInfo?.isConnectedOrConnecting == true
            @Suppress("DEPRECATION")
            val isWifi = networkInfo?.type == ConnectivityManager.TYPE_WIFI
            @Suppress("DEPRECATION")
            val isCellular = networkInfo?.type == ConnectivityManager.TYPE_MOBILE

            return mapOf(
                "isConnected" to isConnected,
                "isValidated" to isConnected,
                "isWifi" to isWifi,
                "isCellular" to isCellular,
                "type" to (if (isWifi) "wifi" else if (isCellular) "cellular" else "none")
            )
        }

        return mapOf(
            "isConnected" to false,
            "isValidated" to false,
            "isWifi" to false,
            "isCellular" to false,
            "type" to "none"
        )
    }

    private fun registerNetworkCallback() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            val cm = connectivityManager ?: return
            unregisterNetworkCallback()

            val callback = object : ConnectivityManager.NetworkCallback() {
                override fun onAvailable(network: Network) {
                    dispatchState(freshNetwork = network)
                }

                override fun onLost(network: Network) {
                    dispatchState(lostNetwork = network)
                }

                override fun onCapabilitiesChanged(network: Network, networkCapabilities: NetworkCapabilities) {
                    dispatchState(freshNetwork = network, freshCapabilities = networkCapabilities)
                }
            }
            networkCallback = callback
            try {
                cm.registerDefaultNetworkCallback(callback)
            } catch (e: Exception) {
                // Fallback if permission or security exception
            }
        }
    }

    private fun unregisterNetworkCallback() {
        networkCallback?.let { callback ->
            try {
                connectivityManager?.unregisterNetworkCallback(callback)
            } catch (e: Exception) {
                // Ignore if already unregistered
            }
            networkCallback = null
        }
    }

    private fun dispatchState(
        lostNetwork: Network? = null,
        freshNetwork: Network? = null,
        freshCapabilities: NetworkCapabilities? = null
    ) {
        mainHandler.post {
            eventSink?.success(checkNetworkState(lostNetwork, freshNetwork, freshCapabilities))
        }
    }

    override fun onDestroy() {
        try {
            speechRecognizer?.destroy()
            speechRecognizer = null
        } catch (_: Exception) {}
        unregisterNetworkCallback()
        super.onDestroy()
    }
}
