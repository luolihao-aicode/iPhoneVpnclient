package com.example.forge_vpn_flutter

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import androidx.core.app.NotificationCompat
import java.io.BufferedReader
import java.io.File
import java.io.FileOutputStream
import java.io.InputStreamReader
import java.util.concurrent.atomic.AtomicBoolean

class ForgeVpnService : VpnService() {

    private var tunFd: ParcelFileDescriptor? = null
    private var singBoxProcess: Process? = null
    private val running = AtomicBoolean(false)
    private var outputReader: Thread? = null
    private var errorReader: Thread? = null

    companion object {
        const val ACTION_CONNECT = "com.example.forge_vpn_flutter.CONNECT"
        const val ACTION_DISCONNECT = "com.example.forge_vpn_flutter.DISCONNECT"
        const val ACTION_RESTART = "com.example.forge_vpn_flutter.RESTART"
        const val CONFIG_EXTRA = "config_json"
        const val BINARY_NAME = "sing-box"

        private const val NOTIFICATION_ID = 1001
        private const val CHANNEL_ID = "forge_vpn_channel"
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_CONNECT -> {
                val configJson = intent.getStringExtra(CONFIG_EXTRA) ?: return START_STICKY
                connect(configJson)
            }
            ACTION_DISCONNECT -> disconnect()
            ACTION_RESTART -> {
                disconnect()
                val configJson = intent.getStringExtra(CONFIG_EXTRA) ?: return START_STICKY
                connect(configJson)
            }
        }
        return START_STICKY
    }

    override fun onDestroy() {
        disconnect()
        super.onDestroy()
    }

    private fun connect(configJson: String) {
        if (running.get()) disconnect()

        try {
            // 1. Build TUN interface
            val builder = Builder()
            builder.setName("tun0")
            builder.addAddress("172.16.0.1", 30)
            builder.addRoute("0.0.0.0", 0)
            builder.addDnsServer("8.8.8.8")
            builder.addDnsServer("1.1.1.1")
            builder.setMtu(1500)
            builder.setBlocking(false)
            builder.setSession(getString(R.string.app_name))

            // Exclude the app itself from VPN routing to avoid loops
            builder.addDisallowedApplication(packageName)

            tunFd = builder.establish()
            if (tunFd == null) {
                sendStatus("error", "Failed to establish TUN interface")
                return
            }

            // 2. Extract sing-box binary from assets
            val binaryFile = extractBinary()
            if (binaryFile == null) {
                sendStatus("error", "sing-box binary not found in assets")
                disconnect()
                return
            }

            // 3. Write config file
            val configDir = File(filesDir, "singbox")
            if (!configDir.exists()) configDir.mkdirs()
            val configFile = File(configDir, "config.json")
            configFile.writeText(configJson)

            // 4. Start foreground notification
            startForeground(NOTIFICATION_ID, buildNotification())

            // 5. Start sing-box with TUN fd
            val fd = tunFd!!.fd
            val cmd = arrayOf(
                binaryFile.absolutePath,
                "run",
                "-c", configFile.absolutePath,
                "-D", configDir.absolutePath,
                "--tun-fd", fd.toString()
            )

            // Protect file descriptors from VPN routing
            protect(fd)

            singBoxProcess = Runtime.getRuntime().exec(cmd)
            running.set(true)
            sendStatus("connected", "")

            // 6. Read stdout/stderr in background threads
            outputReader = Thread {
                try {
                    val reader = BufferedReader(InputStreamReader(singBoxProcess!!.inputStream))
                    var line: String?
                    while (running.get() && reader.readLine().also { line = it } != null) {
                        if (line != null) sendLog(line!!)
                    }
                } catch (_: Exception) {}
            }.apply { isDaemon = true; start() }

            errorReader = Thread {
                try {
                    val reader = BufferedReader(InputStreamReader(singBoxProcess!!.errorStream))
                    var line: String?
                    while (running.get() && reader.readLine().also { line = it } != null) {
                        if (line != null) sendLog("[err] $line")
                    }
                } catch (_: Exception) {}
            }.apply { isDaemon = true; start() }

            // 7. Monitor process exit
            Thread {
                try {
                    val exitCode = singBoxProcess!!.waitFor()
                    if (running.get()) {
                        running.set(false)
                        sendStatus("disconnected", "Exit code: $exitCode")
                        tunFd?.close()
                        tunFd = null
                        stopForeground(STOP_FOREGROUND_REMOVE)
                    }
                } catch (_: Exception) {}
            }.apply { isDaemon = true; start() }

        } catch (e: Exception) {
            sendStatus("error", e.message ?: "Unknown error")
            disconnect()
        }
    }

    private fun disconnect() {
        running.set(false)
        singBoxProcess?.let {
            it.destroy()
            it.waitFor()
        }
        singBoxProcess = null
        tunFd?.close()
        tunFd = null
        stopForeground(STOP_FOREGROUND_REMOVE)
        sendStatus("disconnected", "User stopped")
    }

    private fun extractBinary(): File? {
        val abi = when (Build.SUPPORTED_ABIS.firstOrNull()) {
            "arm64-v8a" -> "arm64"
            "armeabi-v7a" -> "armv7"
            "x86_64" -> "amd64"
            "x86" -> "386"
            else -> return null
        }

        val assetPath = "binaries/sing-box-android-$abi"
        val outFile = File(filesDir, BINARY_NAME)

        return try {
            assets.open(assetPath).use { input ->
                FileOutputStream(outFile).use { output ->
                    input.copyTo(output)
                }
            }
            outFile.setExecutable(true)
            outFile
        } catch (e: Exception) {
            // Binary not bundled yet — could download at runtime
            null
        }
    }

    private fun sendStatus(status: String, message: String) {
        VpnBridge.sendStatus(this, status, message)
    }

    private fun sendLog(line: String) {
        VpnBridge.sendLog(this, line)
    }

    private fun buildNotification(): Notification {
        val pendingIntent = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Forge VPN")
            .setContentText("Connected — securing your traffic")
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setSilent(true)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Forge VPN Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "VPN connection status"
                setShowBadge(false)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }
}
