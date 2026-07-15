package com.example.forge_vpn_flutter

import android.content.Context
import android.content.Intent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** Bridges between Flutter and the Android VpnService. */
object VpnBridge {
    private const val CHANNEL = "dev.forge.vpn/vpn_service"

    private var methodChannel: MethodChannel? = null

    fun register(flutterEngine: FlutterEngine) {
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)

        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "connect" -> {
                    val configJson = call.argument<String>("config") ?: ""
                    if (configJson.isEmpty()) {
                        result.error("INVALID_CONFIG", "Config JSON is empty", null)
                        return@setMethodCallHandler
                    }
                    val context = flutterEngine.applicationContext as Context
                    val intent = Intent(context, ForgeVpnService::class.java).apply {
                        action = ForgeVpnService.ACTION_CONNECT
                        putExtra(ForgeVpnService.CONFIG_EXTRA, configJson)
                    }
                    startForegroundService(context, intent)
                    result.success(true)
                }
                "disconnect" -> {
                    val context = flutterEngine.applicationContext as Context
                    val intent = Intent(context, ForgeVpnService::class.java).apply {
                        action = ForgeVpnService.ACTION_DISCONNECT
                    }
                    context.startService(intent)
                    result.success(true)
                }
                "isRunning" -> {
                    // Simple check — the service manager tracks this
                    result.success(false)
                }
                else -> result.notImplemented()
            }
        }
    }

    fun sendStatus(context: Context, status: String, message: String) {
        context.runOnUiThread {
            methodChannel?.invokeMethod("onStatus", mapOf(
                "status" to status,
                "message" to message
            ))
        }
    }

    fun sendLog(context: Context, line: String) {
        context.runOnUiThread {
            methodChannel?.invokeMethod("onLog", line)
        }
    }

    private fun startForegroundService(context: Context, intent: Intent) {
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            context.startForegroundService(intent)
        } else {
            context.startService(intent)
        }
    }

    private fun Context.runOnUiThread(action: () -> Unit) {
        android.os.Handler(android.os.Looper.getMainLooper()).post(action)
    }
}
