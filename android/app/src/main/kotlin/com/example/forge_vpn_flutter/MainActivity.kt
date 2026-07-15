package com.example.forge_vpn_flutter

import android.content.Intent
import android.net.VpnService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        VpnBridge.register(flutterEngine)
    }

    /** Convenience method for apps that need to check VPN permission at runtime. */
    fun requestVpnPermission(): Boolean {
        val intent = VpnService.prepare(this)
        return if (intent != null) {
            startActivityForResult(intent, VPN_REQUEST_CODE)
            false
        } else {
            true  // Already granted
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == VPN_REQUEST_CODE) {
            val granted = resultCode == RESULT_OK
            VpnBridge.sendStatus(this, if (granted) "permission_granted" else "permission_denied", "")
        }
    }

    companion object {
        private const val VPN_REQUEST_CODE = 9001
    }
}
