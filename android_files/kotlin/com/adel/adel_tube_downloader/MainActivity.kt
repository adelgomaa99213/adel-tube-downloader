package com.adel.adel_tube_downloader

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var shareChannel: MethodChannel? = null
    private var pendingShare: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        YtDlpPlugin.register(flutterEngine, applicationContext)

        shareChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "adel_tube/share")
            .also { ch ->
                ch.setMethodCallHandler { call, result ->
                    if (call.method == "getInitial") {
                        result.success(pendingShare)
                        pendingShare = null
                    } else result.notImplemented()
                }
            }
        pendingShare = extractShared(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        extractShared(intent)?.let { shareChannel?.invokeMethod("onShared", it) }
    }

    private fun extractShared(i: Intent?): String? =
        if (i?.action == Intent.ACTION_SEND && i.type == "text/plain")
            i.getStringExtra(Intent.EXTRA_TEXT) else null
}
