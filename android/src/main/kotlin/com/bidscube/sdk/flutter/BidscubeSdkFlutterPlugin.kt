package com.bidscube.sdk.flutter

import android.app.Activity
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.View
import com.bidscube.sdk.BidscubeSDK
import com.bidscube.sdk.config.SDKConfig
import com.bidscube.sdk.interfaces.AdCallback
import com.bidscube.sdk.interfaces.ConsentCallback
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
                loadNativeAdView(placementId, NativeAdKind.IMAGE, call, result)
            }
            "getVideoAdView" -> {
                val placementId = call.argument<String>("placementId")
                loadNativeAdView(placementId, NativeAdKind.VIDEO, call, result)
            }
            "getNativeAdView" -> {
                val placementId = call.argument<String>("placementId")
                loadNativeAdView(placementId, NativeAdKind.NATIVE, call, result)
            }
            "getBannerAdView" -> {
                val placementId = call.argument<String>("placementId")
                loadNativeAdView(placementId, NativeAdKind.BANNER, call, result)
            }
            "showVideoAdFromVast" -> showVideoAdFromVast(call, result)
            "requestAd", "removeAdCallback" -> result.success(null)
            "isConsentRequired" -> result.success(BidscubeSDK.isConsentRequired())
            "hasAdsConsent" -> result.success(BidscubeSDK.hasAdsConsent())
            "hasAnalyticsConsent" -> result.success(BidscubeSDK.hasAnalyticsConsent())
            "getConsentStatusSummary" -> result.success(BidscubeSDK.getConsentStatusSummary())
            "enableConsentDebugMode" -> {
                val deviceId = call.argument<String>("testDeviceId") ?: ""
                BidscubeSDK.enableConsentDebugMode(deviceId)
                result.success(null)
            }
            "resetConsent" -> {
                BidscubeSDK.resetConsent()
                result.success(null)
            }
            "setUserId" -> {
                val userId = call.argument<String>("userId")
                if (BidscubeSDK.isInitialized()) {
                    BidscubeSDK.setUserId(userId)
                }
                result.success(null)
            }
            "requestConsentInfoUpdate" -> requestConsentInfoUpdate(result)
            "showConsentForm" -> showConsentForm(result)
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
            Log.i(
                TAG,
                "[BidsCubeDiag] bidscube_native init_ok BidscubeSDK.initialize finished",
            )
            if (integrationMode == "appLovinMax" || integrationMode == "levelPlay") {
                Log.i(
                    TAG,
                    "[BidsCubeDiag] applovin_max Host must initialize AppLovin MAX in the Android app; " +
                        "Bidscube–MAX link is in the mediation adapter (see native / Logcat).",
                )
            }
            result.success("ok")
        } catch (e: Exception) {
            Log.e(TAG, "[BidsCubeDiag] bidscube_native init_failed ${e.message}", e)
            result.error("INITIALIZATION_ERROR", e.message, null)
        }
    }

    /**
     * Forwards Dart [SDKConfig] fields when the linked native AAR exposes matching
     * [SDKConfig.Builder] methods (API differs by bidscube-sdk version).
     */
    private fun applyOptionalFlutterConfig(builder: SDKConfig.Builder, map: Map<String, Any?>) {
        val adRequestAuthority = (map["adRequestAuthority"] as? String)?.trim()?.takeIf { it.isNotEmpty() }
        if (adRequestAuthority != null) {
            val invokedAuth = invokeFirstMatchingMethod(
                builder,
                listOf("adRequestAuthority", "setAdRequestAuthority", "setRequestAuthority"),
                arrayOf(String::class.java),
                arrayOf(adRequestAuthority),
            )
            if (!invokedAuth) {
                Log.w(
                    TAG,
                    "SDKConfig.Builder has no adRequestAuthority setter; Dart adRequestAuthority ignored on this native SDK version",
                )
            }
        }
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
        val userId = (map["userId"] as? String)?.trim()?.takeIf { it.isNotEmpty() }
            ?: (map["user_id"] as? String)?.trim()?.takeIf { it.isNotEmpty() }
        if (userId != null) {
            val invoked = invokeFirstMatchingMethod(
                builder,
                listOf("userId", "setUserId"),
                arrayOf(String::class.java),
                arrayOf(userId),
            )
            if (!invoked) {
                Log.w(
                    TAG,
                    "SDKConfig.Builder has no userId setter; Dart userId ignored on this native SDK version",
                )
            }
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

    private fun requestConsentInfoUpdate(result: MethodChannel.Result) {
        val messenger = flutterBinding?.binaryMessenger ?: run {
            result.error("NO_ENGINE", "Flutter engine not available", null)
            return
        }
        if (!BidscubeSDK.isInitialized()) {
            result.error("NOT_INITIALIZED", "BidscubeSDK is not initialized", null)
            return
        }
        BidscubeSDK.requestConsentInfoUpdate(
            DartConsentCallback(MethodChannel(messenger, CHANNEL_NAME), result),
        )
    }

    private fun showConsentForm(result: MethodChannel.Result) {
        val messenger = flutterBinding?.binaryMessenger ?: run {
            result.error("NO_ENGINE", "Flutter engine not available", null)
            return
        }
        if (!BidscubeSDK.isInitialized()) {
            result.error("NOT_INITIALIZED", "BidscubeSDK is not initialized", null)
            return
        }
        BidscubeSDK.showConsentForm(
            DartConsentCallback(MethodChannel(messenger, CHANNEL_NAME), result),
        )
    }

    private fun loadNativeAdView(
        placementId: String?,
        kind: NativeAdKind,
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        if (placementId.isNullOrBlank()) {
            result.error("INVALID_PLACEMENT_ID", "placementId is required", null)
            return
        }
        Log.i(
            TAG,
            "[BidsCubeDiag] ad_load_native placement=$placementId kind=$kind",
        )
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
            val (defaultWidth, defaultHeight) = defaultSizeForKind(kind)
            val width = (call.argument<Number>("width")?.toDouble() ?: defaultWidth).toInt()
            val height = (call.argument<Number>("height")?.toDouble() ?: defaultHeight).toInt()
            val measuredWidth = if (view.width > 0) view.width else width
            val measuredHeight = if (view.height > 0) view.height else height
            result.success(
                mapOf(
                    "viewKey" to viewKey,
                    "width" to measuredWidth.toDouble(),
                    "height" to measuredHeight.toDouble(),
                ),
            )
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

    private fun showVideoAdFromVast(call: MethodCall, result: MethodChannel.Result) {
        val placementId = call.argument<String>("placementId")
        val vastXml = call.argument<String>("vastXml")
        if (placementId.isNullOrBlank()) {
            result.error("INVALID_PLACEMENT_ID", "placementId is required", null)
            return
        }
        if (vastXml.isNullOrBlank()) {
            result.error("INVALID_VAST", "vastXml is required", null)
            return
        }
        val act = activity
        if (act == null) {
            result.error("NO_ACTIVITY", "Activity is required to show video ads", null)
            return
        }
        if (!BidscubeSDK.isInitialized()) {
            result.error("NOT_INITIALIZED", "BidscubeSDK is not initialized", null)
            return
        }
        val messenger = flutterBinding?.binaryMessenger ?: run {
            result.error("NO_ENGINE", "Flutter engine not available", null)
            return
        }
        try {
            BidscubeSDK.setActivity(act)
            val cb = VastShowAdCallback(MethodChannel(messenger, CHANNEL_NAME), result)
            Log.i(TAG, "[BidsCubeDiag] showVideoAdFromVast placement=$placementId vastChars=${vastXml.length}")
            invokeShowVideoAdFromVastMarkup(placementId, vastXml, cb)
        } catch (e: NoSuchMethodException) {
            Log.w(TAG, "showVideoAdFromVastMarkup not in bidscube-sdk AAR; use VastVideoAdView or upgrade AAR")
            result.error(
                "NOT_SUPPORTED",
                "Native showVideoAdFromVastMarkup requires a newer bidscube-sdk AAR in android/libs/",
                null,
            )
        } catch (e: Exception) {
            Log.e(TAG, "showVideoAdFromVast failed: ${e.message}", e)
            result.error("VAST_SHOW_ERROR", e.message, null)
        }
    }

    /** Maven 1.0.0 AAR may omit VAST markup API; reflection keeps the plugin buildable. */
    private fun invokeShowVideoAdFromVastMarkup(
        placementId: String,
        vastXml: String,
        callback: AdCallback,
    ) {
        val method = BidscubeSDK::class.java.getMethod(
            "showVideoAdFromVastMarkup",
            String::class.java,
            String::class.java,
            AdCallback::class.java,
        )
        method.invoke(null, placementId, vastXml, callback)
    }

    private fun defaultSizeForKind(kind: NativeAdKind): Pair<Double, Double> = when (kind) {
        NativeAdKind.BANNER -> 320.0 to 50.0
        NativeAdKind.VIDEO -> 320.0 to 180.0
        NativeAdKind.NATIVE -> 320.0 to 250.0
        NativeAdKind.IMAGE -> 320.0 to 50.0
    }

    private enum class NativeAdKind { IMAGE, VIDEO, NATIVE, BANNER }

    companion object {
        private const val TAG = "BidscubeFlutter"
        private const val CHANNEL_NAME = "bidscube_sdk"
        private const val PLATFORM_VIEW_TYPE = "bidscube_native_ad"
    }
}

/** Forwards native [ConsentCallback] events to Dart. */
private class DartConsentCallback(
    private val channel: MethodChannel,
    private val result: MethodChannel.Result,
) : ConsentCallback {
    private val finished = java.util.concurrent.atomic.AtomicBoolean(false)

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

    private fun finishSuccess() {
        if (!finished.compareAndSet(false, true)) return
        runMain { result.success(null) }
    }

    private fun finishError(code: String, message: String) {
        if (!finished.compareAndSet(false, true)) return
        runMain { result.error(code, message, null) }
    }

    override fun onConsentInfoUpdated() {
        push("onConsentInfoUpdated", mapOf("placementId" to "_consent_"))
        finishSuccess()
    }

    override fun onConsentInfoUpdateFailed(error: Exception?) {
        finishError("CONSENT_INFO_FAILED", error?.message ?: "Consent info update failed")
    }

    override fun onConsentFormShown() {
        push("onConsentFormShown", mapOf("placementId" to "_consent_"))
    }

    override fun onConsentFormError(error: Exception?) {
        finishError("CONSENT_FORM_ERROR", error?.message ?: "Consent form error")
    }

    override fun onConsentGranted() {
        push("onConsentGranted", mapOf("placementId" to "_consent_"))
        finishSuccess()
    }

    override fun onConsentDenied() {
        push("onConsentDenied", mapOf("placementId" to "_consent_"))
        finishSuccess()
    }

    override fun onConsentNotRequired() {
        push("onConsentNotRequired", mapOf("placementId" to "_consent_"))
        finishSuccess()
    }

    override fun onConsentStatusChanged(hasConsent: Boolean) {
        push("onConsentStatusChanged", mapOf("placementId" to "_consent_", "hasConsent" to hasConsent))
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

/**
 * Forwards ad events to Dart and completes the Flutter [MethodChannel.Result]
 * when the fullscreen VAST flow ends ([onAdClosed] or [onAdFailed]).
 */
private class VastShowAdCallback(
    private val channel: MethodChannel,
    private val result: MethodChannel.Result,
) : AdCallback {
    private val finished = java.util.concurrent.atomic.AtomicBoolean(false)

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

    private fun finishSuccess() {
        if (!finished.compareAndSet(false, true)) return
        runMain { result.success(null) }
    }

    private fun finishError(code: Int, message: String) {
        if (!finished.compareAndSet(false, true)) return
        runMain { result.error("AD_FAILED", message, mapOf("errorCode" to code)) }
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
        finishSuccess()
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
        finishError(errorCode, errorMessage)
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

    override fun onVideoAdSkippable(placementId: String) {
        push("onVideoAdSkippable", mapOf("placementId" to placementId))
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
