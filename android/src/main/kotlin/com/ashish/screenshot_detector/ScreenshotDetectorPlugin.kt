package com.ashish.screenshot_detector

import android.app.Activity
import android.content.Context
import android.database.ContentObserver
import android.net.Uri
import android.os.Handler
import android.provider.MediaStore
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodChannel

class ScreenshotDetectorPlugin: FlutterPlugin, ActivityAware {
  private lateinit var channel : MethodChannel
  private var observer: ContentObserver? = null
  private var context: Context? = null

  override fun onAttachedToEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(binding.binaryMessenger, "screenshot_detector")
    context = binding.applicationContext
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    observer = object : ContentObserver(Handler()) {
      override fun onChange(selfChange: Boolean, uri: Uri?) {
        super.onChange(selfChange, uri)
        channel.invokeMethod("onScreenshot", null)
      }
    }
    context?.contentResolver?.registerContentObserver(
      MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
      true,
      observer!!
    )
  }

  override fun onDetachedFromActivityForConfigChanges() {}
  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {}
  override fun onDetachedFromActivity() {
    observer?.let { context?.contentResolver?.unregisterContentObserver(it) }
  }
  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {}
}

