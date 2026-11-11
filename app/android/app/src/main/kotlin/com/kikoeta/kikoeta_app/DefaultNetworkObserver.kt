package com.kikoeta.kikoeta_app

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** The cached Flutter engine continues making requests without an Activity. */
object DefaultNetworkObserver {
    private val mainHandler = Handler(Looper.getMainLooper())
    private var channel: MethodChannel? = null
    private var registered = false

    fun register(context: Context, engine: FlutterEngine) {
        channel = MethodChannel(engine.dartExecutor.binaryMessenger, "kikoeta/network")
        if (registered) return

        val connectivity = context.getSystemService(ConnectivityManager::class.java) ?: return
        connectivity.registerDefaultNetworkCallback(object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) = notifyChanged()

            override fun onLost(network: Network) = notifyChanged()
        })
        registered = true
    }

    private fun notifyChanged() {
        mainHandler.post { channel?.invokeMethod("defaultNetworkChanged", null) }
    }
}
