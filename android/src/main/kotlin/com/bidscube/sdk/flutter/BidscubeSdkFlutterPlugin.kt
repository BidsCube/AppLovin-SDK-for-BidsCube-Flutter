package com.bidscube.sdk.flutter

import android.app.Activity
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.View
import com.bidscube.sdk.BidscubeSDK
import com.bidscube.sdk.config.SDKConfig
import com.bidscube.sdk.interfaces.AdCallback
import com.bidscube.sdk.models.enums.AdPosition
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

/**
 * Flutter glue for native Bidscube SDK. Supports:
 * - Direct embedding of native ad [View]s in Flutter (PlatformView)
 * - Early initialization so AppLovin MAX mediation adapters share the same SDK instance
 */
class BidscubeSdkFlutterPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {
    private lateinit var channel: MethodChannel
    private lateinit var appContext: android.content.Context
    private var flutterBinding: FlutterPlugin.FlutterPluginBinding? = null
    private var activity: Activity? = null
    private val viewRegistry = ConcurrentHashMap<String, View>()

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        flutterBinding = binding
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
        appContext = binding.applicationContext
        binding.platformViewRegistry.registerViewFactory(
            PLATFORM_VIEW_TYPE,
            BidscubeNativeAdPlatformViewFactory(viewRegistry),
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        flutterBinding = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        try {
            BidscubeSDK.setActivity(binding.activity)
        } catch (_: Throwable) {
            // SDK may not be initialized yet
        }
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        try {
            BidscubeSDK.setActivity(binding.activity)
        } catch (_: Throwable) {
        }
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initialize" -> {
                @Suppress("UNCHECKED_CAST")
                val map = call.arguments as? Map<String, Any?> ?: emptyMap()
                initializeSdk(map, result)
            }
            "getImageAdView" -> {
                val placementId = call.argument<String>("placementId")
                loadNativeAdView(placementId, NativeAdKind.IMAGE, result)
            }
            "getVideoAdView" -> {
                val placementId = call.argument<String>("placementId")
                loadNativeAdView(placementId, NativeAdKind.VIDEO, result)
            }
            "getNativeAdView" -> {
                val placementId = call.argument<String>("placementId")
                loadNativeAdView(placementId, NativeAdKind.NATIVE, result)
            }
            "getBannerAdView" -> {
                val placementId = call.argument<String>("placementId")
                loadNativeAdView(placementId, NativeAdKind.BANNER, result)
            }
            "requestAd", "removeAdCallback" -> result.success(null)
            "requestConsentInfoUpdate" -> result.success("ok")
            "showConsentForm" -> result.success("ok")
            "getSKAdNetworkIds" -> result.success(emptyList<String>())
            else -> result.notImplemented()
        }
    }

    private fun initializeSdk(map: Map<String, Any?>, result: MethodChannel.Result) {
        try {
            val integrationMode = map["integrationMode"] as? String ?: "direct"
            Log.i(TAG, "BidsCube SDK initializing (integrationMode=$integrationMode)")

            val builder = SDKConfig.Builder(appContext)
                .enableLogging(map["enableLogging"] as? Boolean ?: true)
                .enableDebugMode(map["enableDebugMode"] as? Boolean ?: false)
                .defaultAdTimeout((map["defaultAdTimeout"] as? Number)?.toInt() ?: 30_000)
            val posRaw = map["defaultAdPosition"] as? String ?: "unknown"
            builder.defaultAdPosition(mapFlutterAdPosition(posRaw))
            applyOptionalFlutterConfig(builder, map)
            val config = builder.build()
            BidscubeSDK.initialize(appContext, config)
            activity?.let { act ->
                try {
                    BidscubeSDK.setActivity(act)
                } catch (_: Throwable) {
                }
            }
            result.success("ok")
        } catch (e: Exception) {
            result.error("INITIALIZATION_ERROR", e.message, null)
        }
    }

    /**
     * Forwards Dart [SDKConfig] fields when the linked native AAR exposes matching
     * [SDKConfig.Builder] methods (API differs by bidscube-sdk version).
     */
    private fun applyOptionalFlutterConfig(builder: SDKConfig.Builder, map: Map<String, Any?>) {
        val baseURL = (map["baseURL"] as? String)?.trim()?.takeIf { it.isNotEmpty() }
        if (baseURL != null) {
            val invoked = invokeFirstMatchingMethod(
                builder,
                listOf("baseURL", "setBaseUrl", "setBaseURL"),
                arrayOf(String::class.java),
                arrayOf(baseURL),
            )
            if (!invoked) {
                Log.w(
                    TAG,
                    "SDKConfig.Builder has no baseURL setter; Dart baseURL ignored on this native SDK version",
                )
            }
        }
        val testMode = map["enableTestMode"] as? Boolean
        if (testMode != null) {
            invokeFirstMatchingMethod(
                builder,
                listOf("enableTestMode", "setEnableTestMode", "setTestMode"),
                arrayOf(java.lang.Boolean.TYPE),
                arrayOf(testMode),
            )
        }
    }

    private fun invokeFirstMatchingMethod(
        target: Any,
        methodNames: List<String>,
        paramTypes: Array<Class<*>>,
        args: Array<Any?>,
    ): Boolean {
        val clazz = target.javaClass
        for (name in methodNames) {
            val ok = runCatching {
                clazz.getMethod(name, *paramTypes).invoke(target, *args)
            }.isSuccess
            if (ok) return true
        }
        return false
    }

    private fun loadNativeAdView(
        placementId: String?,
        kind: NativeAdKind,
        result: MethodChannel.Result,
    ) {
        if (placementId.isNullOrBlank()) {
            result.error("INVALID_PLACEMENT_ID", "placementId is required", null)
            return
        }
        val messenger = flutterBinding?.binaryMessenger ?: run {
            result.error("NO_ENGINE", "Flutter engine not available", null)
            return
        }
        val viewKey = UUID.randomUUID().toString()
        val cb = DartAdCallback(MethodChannel(messenger, CHANNEL_NAME))

        try {
            val view: View = when (kind) {
                NativeAdKind.IMAGE -> BidscubeSDK.getImageAdView(placementId, cb)
                NativeAdKind.VIDEO -> BidscubeSDK.getVideoAdView(placementId, cb)
                NativeAdKind.NATIVE -> BidscubeSDK.getNativeAdView(placementId, cb)
                NativeAdKind.BANNER -> BidscubeSDK.getImageAdView(placementId, cb)
            }
            viewRegistry[viewKey] = view
            result.success(mapOf("viewKey" to viewKey))
        } catch (e: Exception) {
            result.error("NATIVE_AD_ERROR", e.message, null)
        }
    }

    private fun mapFlutterAdPosition(raw: String): String {
        val normalized = raw.lowercase().replace(" ", "_")
        if (normalized == "depend_on_the_screen_size") {
            return AdPosition.MAYBE_DEPENDING_ON_SCREEN_SIZE.name
        }
        return AdPosition.fromString(normalized).name
    }

    private enum class NativeAdKind { IMAGE, VIDEO, NATIVE, BANNER }

    companion object {
        private const val TAG = "BidscubeFlutter"
        private const val CHANNEL_NAME = "bidscube_sdk"
        private const val PLATFORM_VIEW_TYPE = "bidscube_native_ad"
    }
}

/** Forwards native [AdCallback] events to Dart via the same [MethodChannel] name. */
private class DartAdCallback(private val channel: MethodChannel) : AdCallback {
    private fun runMain(block: () -> Unit) {
        if (Looper.myLooper() == Looper.getMainLooper()) {
            block()
        } else {
            Handler(Looper.getMainLooper()).post { block() }
        }
    }

    private fun push(method: String, args: Map<String, Any?>) {
        runMain { channel.invokeMethod(method, args) }
    }

    override fun onAdLoading(placementId: String) {
        push("onAdLoading", mapOf("placementId" to placementId))
    }

    override fun onAdLoaded(placementId: String) {
        push("onAdLoaded", mapOf("placementId" to placementId))
    }

    override fun onAdDisplayed(placementId: String) {
        push("onAdDisplayed", mapOf("placementId" to placementId))
    }

    override fun onAdClicked(placementId: String) {
        push("onAdClicked", mapOf("placementId" to placementId))
    }

    override fun onAdClosed(placementId: String) {
        push("onAdClosed", mapOf("placementId" to placementId))
    }

    override fun onAdFailed(placementId: String, errorCode: Int, errorMessage: String) {
        push(
            "onAdFailed",
            mapOf(
                "placementId" to placementId,
                "errorCode" to errorCode.toString(),
                "errorMessage" to errorMessage,
            ),
        )
    }

    override fun onVideoAdStarted(placementId: String) {
        push("onVideoAdStarted", mapOf("placementId" to placementId))
    }

    override fun onVideoAdCompleted(placementId: String) {
        push("onVideoAdCompleted", mapOf("placementId" to placementId))
    }

    override fun onVideoAdSkipped(placementId: String) {
        push("onVideoAdSkipped", mapOf("placementId" to placementId))
    }
}

private class BidscubeNativeAdPlatformViewFactory(
    private val registry: ConcurrentHashMap<String, View>,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: android.content.Context, viewId: Int, args: Any?): PlatformView {
        val params = args as? Map<*, *>
        val key = params?.get("viewKey") as? String
        val v = if (!key.isNullOrEmpty()) registry[key] else null
        return object : PlatformView {
            override fun getView(): View {
                return v ?: View(context).apply {
                    setBackgroundColor(0xFFE0E0E0.toInt())
                }
            }

            override fun dispose() {
                if (!key.isNullOrEmpty()) {
                    registry.remove(key)
                }
            }
        }
    }
}
