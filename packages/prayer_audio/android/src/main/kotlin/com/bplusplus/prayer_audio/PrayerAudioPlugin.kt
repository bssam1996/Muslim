package com.bplusplus.prayer_audio

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class PrayerAudioPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var context: Context
    private lateinit var channel: MethodChannel

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        if (!AdhanPlaybackService.running) AdhanPlaybackService.restoreVolume(context)
        channel = MethodChannel(binding.binaryMessenger, "com.bplusplus.muslim/prayer_audio")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "schedule" -> {
                    AdhanAlarms.schedule(context, JSONObject(call.arguments as Map<*, *>))
                    result.success(null)
                }
                "cancel" -> {
                    AdhanAlarms.cancel(context, call.argument<Number>("id")!!.toInt())
                    result.success(null)
                }
                "pendingIds" -> result.success(AdhanAlarms.pendingIds(context))
                "stop" -> {
                    AdhanPlaybackService.stopAllPrayerAudio(context)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (error: Exception) {
            result.error(if (error is SecurityException) "exact_alarms_not_permitted" else "prayer_audio_failed", error.message, null)
        }
    }
}
