package com.ashish.screenshot_detector

import android.app.Activity
import android.content.Context
import android.database.ContentObserver
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.view.WindowManager
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.time.Instant

class ScreenshotDetectorPlugin :
  FlutterPlugin,
  ActivityAware,
  MethodChannel.MethodCallHandler {

  private lateinit var channel: MethodChannel
  private var context: Context? = null
  private var activity: Activity? = null

  private var imageObserver: ContentObserver? = null
  private var recordingCallback: Any? = null

  private var screenshotProtectionEnabled: Boolean = false
  private var recordingProtectionMode: String = "off"

  override fun onAttachedToEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(binding.binaryMessenger, "screenshot_detector")
    channel.setMethodCallHandler(this)
    context = binding.applicationContext
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
    context = null
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activity = binding.activity
    applyWindowProtection()
    registerScreenshotObserver()
    registerScreenRecordingCallbackIfSupported()
  }

  override fun onDetachedFromActivityForConfigChanges() {
    unregisterObservers()
    activity = null
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    activity = binding.activity
    applyWindowProtection()
    registerScreenshotObserver()
    registerScreenRecordingCallbackIfSupported()
  }

  override fun onDetachedFromActivity() {
    unregisterObservers()
    activity = null
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    when (call.method) {
      "setScreenshotProtectionEnabled" -> {
        screenshotProtectionEnabled = (call.argument<Boolean>("enabled") == true)
        applyWindowProtection()
        result.success(null)
      }

      "setScreenRecordingProtection" -> {
        recordingProtectionMode = call.argument<String>("mode") ?: "off"
        applyWindowProtection()
        result.success(null)
      }

      "getDeviceInfo" -> {
        result.success(
          mapOf(
            "manufacturer" to Build.MANUFACTURER,
            "brand" to Build.BRAND,
            "model" to Build.MODEL,
            "device" to Build.DEVICE,
            "sdkInt" to Build.VERSION.SDK_INT,
          ),
        )
      }

      else -> result.notImplemented()
    }
  }

  private fun registerScreenshotObserver() {
    val appContext = context ?: return
    if (imageObserver != null) {
      return
    }

    imageObserver = object : ContentObserver(Handler(Looper.getMainLooper())) {
      override fun onChange(selfChange: Boolean, uri: Uri?) {
        super.onChange(selfChange, uri)

        val filePath = resolveImagePath(appContext, uri)
        emitEvent(
          eventType = "screenshot",
          filePath = filePath,
          raw = mapOf("source" to "media_store_images"),
        )

        // Legacy callback for existing app integrations.
        channel.invokeMethod("onScreenshot", null)
      }
    }

    appContext.contentResolver.registerContentObserver(
      MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
      true,
      imageObserver!!,
    )
  }

  private fun unregisterObservers() {
    val appContext = context
    if (appContext != null && imageObserver != null) {
      appContext.contentResolver.unregisterContentObserver(imageObserver!!)
      imageObserver = null
    }

    unregisterScreenRecordingCallbackIfSupported()
  }

  private fun emitEvent(eventType: String, filePath: String?, raw: Map<String, Any?>) {
    val payload = mutableMapOf<String, Any?>(
      "eventType" to eventType,
      "timestamp" to nowIso(),
      "platform" to "android",
      "filePath" to filePath,
      "raw" to raw,
    )
    channel.invokeMethod("onSecurityEvent", payload)
  }

  private fun applyWindowProtection() {
    val currentActivity = activity ?: return
    val shouldSecure = screenshotProtectionEnabled || recordingProtectionMode != "off"

    if (shouldSecure) {
      currentActivity.window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
    } else {
      currentActivity.window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }
  }

  private fun resolveImagePath(context: Context, uri: Uri?): String? {
    if (uri != null) {
      return uri.toString()
    }

    val projection = arrayOf(
      MediaStore.Images.Media._ID,
    )

    context.contentResolver.query(
      MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
      projection,
      null,
      null,
      "${MediaStore.Images.Media.DATE_ADDED} DESC",
    )?.use { cursor ->
      if (cursor.moveToFirst()) {
        val id = cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.Images.Media._ID))
        return Uri.withAppendedPath(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, id.toString())
          .toString()
      }
    }

    return null
  }

  private fun nowIso(): String {
    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      Instant.now().toString()
    } else {
      java.util.Date().toInstant().toString()
    }
  }

  private fun registerScreenRecordingCallbackIfSupported() {
    val currentActivity = activity ?: return
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
      return
    }
    if (recordingCallback != null) {
      return
    }

    val callback = java.util.function.Consumer<Int> { state ->
      when (state) {
        WindowManager.SCREEN_RECORDING_STATE_VISIBLE -> {
          emitEvent(
            eventType = "recordingStarted",
            filePath = null,
            raw = mapOf("source" to "screen_recording_callback"),
          )
        }

        WindowManager.SCREEN_RECORDING_STATE_NOT_VISIBLE -> {
          emitEvent(
            eventType = "recordingStopped",
            filePath = null,
            raw = mapOf("source" to "screen_recording_callback"),
          )
        }
      }
    }

    currentActivity.windowManager.addScreenRecordingCallback(currentActivity.mainExecutor, callback)
    recordingCallback = callback
  }

  private fun unregisterScreenRecordingCallbackIfSupported() {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
      return
    }

    val currentActivity = activity ?: return
    val callback = recordingCallback as? java.util.function.Consumer<Int> ?: return
    currentActivity.windowManager.removeScreenRecordingCallback(callback)
    recordingCallback = null
  }
}
