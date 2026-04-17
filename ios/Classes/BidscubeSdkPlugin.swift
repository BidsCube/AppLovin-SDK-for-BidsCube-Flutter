import Flutter
import UIKit
import bidscubeSdk

public class BidscubeSdkPlugin: NSObject, FlutterPlugin {
    private var registrar: FlutterPluginRegistrar?
    private var methodChannel: FlutterMethodChannel?
    private var adDelegates: [String: FlutterAdDelegate] = [:]

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "bidscube_sdk", binaryMessenger: registrar.messenger())
        let instance = BidscubeSdkPlugin()
        instance.registrar = registrar
        instance.methodChannel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initialize":
            let config = call.arguments as? [String: Any]
            initializeSDK(config: config, result: result)
        case "getImageAdView":
            let args = call.arguments as? [String: Any]
            let placementId = args?["placementId"] as? String
            getImageAdView(placementId: placementId, result: result)
        case "getVideoAdView":
            let args = call.arguments as? [String: Any]
            let placementId = args?["placementId"] as? String
            getVideoAdView(placementId: placementId, result: result)
        case "getNativeAdView":
            let args = call.arguments as? [String: Any]
            let placementId = args?["placementId"] as? String
            getNativeAdView(placementId: placementId, result: result)
        case "getBannerAdView":
            let args = call.arguments as? [String: Any]
            let placementId = args?["placementId"] as? String
            getBannerAdView(placementId: placementId, result: result)
        case "requestAd":
            let args = call.arguments as? [String: Any]
            let placementId = args?["placementId"] as? String
            let adType = args?["adType"] as? String
            let position = args?["position"] as? String
            requestAd(placementId: placementId, adType: adType, position: position, result: result)
        case "removeAdCallback":
            let args = call.arguments as? [String: Any]
            let placementId = args?["placementId"] as? String
            removeAdCallback(placementId: placementId, result: result)
        case "requestConsentInfoUpdate":
            requestConsentInfoUpdate(result: result)
        case "showConsentForm":
            showConsentForm(result: result)
        case "getSKAdNetworkIds":
            getSKAdNetworkIds(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func initializeSDK(config: [String: Any]?, result: @escaping FlutterResult) {
        do {
            let baseURL = config?["baseURL"] as? String ?? "https://ssp-bcc-ads.com/sdk"
            let enableLogging = config?["enableLogging"] as? Bool ?? true
            let enableDebugMode = config?["enableDebugMode"] as? Bool ?? false
            let defaultAdTimeout = config?["defaultAdTimeout"] as? Int ?? 30000
            let integrationMode = config?["integrationMode"] as? String ?? "direct"

            let sdkConfig = SDKConfig.Builder()
                .baseURL(baseURL)
                .enableLogging(enableLogging)
                .enableDebugMode(enableDebugMode)
                .defaultAdTimeout(defaultAdTimeout)
                .build()

            BidscubeSDK.initialize(config: sdkConfig)

            print("📱 [NATIVE] BidsCube SDK initialized (integrationMode=\(integrationMode))")
            print("[BidsCubeDiag] bidscube_native init_ok BidscubeSDK.initialize finished")
            if integrationMode == "appLovinMax" || integrationMode == "levelPlay" {
                print("[BidsCubeDiag] applovin_max Initialize AppLovin MAX in the iOS app; adapter wiring is native (see Xcode console / adapter docs).")
            }
            result("ok")
        } catch {
            print("📱 [NATIVE] Error initializing SDK: \(error)")
            print("[BidsCubeDiag] bidscube_native init_failed \(error.localizedDescription)")
            result(FlutterError(code: "INITIALIZATION_ERROR", message: "Failed to initialize SDK: \(error.localizedDescription)", details: nil))
        }
    }

    private func makeDelegate() -> FlutterAdDelegate {
        FlutterAdDelegate(channel: methodChannel)
    }

    private func registerAndReturnViewId(
        adView: UIView,
        placementId: String,
        storageKey: String,
        delegate: FlutterAdDelegate,
        result: @escaping FlutterResult
    ) {
        adDelegates[storageKey] = delegate
        let viewFactory = NativeAdViewFactory(adView: adView)
        let viewId = "bc_native_\(UUID().uuidString)"
        registrar?.register(viewFactory, withId: viewId)
        result(["viewId": viewId])
    }

    private func getImageAdView(placementId: String?, result: @escaping FlutterResult) {
        guard let placementId = placementId else {
            result(FlutterError(code: "INVALID_PLACEMENT_ID", message: "Placement ID is required", details: nil))
            return
        }
        let adDelegate = makeDelegate()
        let imageAdView = BidscubeSDK.getImageAdView(placementId, adDelegate)
        registerAndReturnViewId(
            adView: imageAdView,
            placementId: placementId,
            storageKey: "image_\(placementId)",
            delegate: adDelegate,
            result: result
        )
    }

    private func getVideoAdView(placementId: String?, result: @escaping FlutterResult) {
        guard let placementId = placementId else {
            result(FlutterError(code: "INVALID_PLACEMENT_ID", message: "Placement ID is required", details: nil))
            return
        }
        print("[BidsCubeDiag] ad_load_native placement=\(placementId) kind=video")
        let adDelegate = makeDelegate()
        let videoAdView = BidscubeSDK.getVideoAdView(placementId, adDelegate)
        registerAndReturnViewId(
            adView: videoAdView,
            placementId: placementId,
            storageKey: "video_\(placementId)",
            delegate: adDelegate,
            result: result
        )
    }

    private func getNativeAdView(placementId: String?, result: @escaping FlutterResult) {
        guard let placementId = placementId else {
            result(FlutterError(code: "INVALID_PLACEMENT_ID", message: "Placement ID is required", details: nil))
            return
        }
        let adDelegate = makeDelegate()
        let nativeAdView = BidscubeSDK.getNativeAdView(placementId, adDelegate)
        registerAndReturnViewId(
            adView: nativeAdView,
            placementId: placementId,
            storageKey: "native_\(placementId)",
            delegate: adDelegate,
            result: result
        )
    }

    /// Banner / image inventory: same native path as the MAX banner adapter (`getImageAdView`).
    private func getBannerAdView(placementId: String?, result: @escaping FlutterResult) {
        guard let placementId = placementId else {
            result(FlutterError(code: "INVALID_PLACEMENT_ID", message: "Placement ID is required", details: nil))
            return
        }
        let adDelegate = makeDelegate()
        let bannerView = BidscubeSDK.getImageAdView(placementId, adDelegate)
        registerAndReturnViewId(
            adView: bannerView,
            placementId: placementId,
            storageKey: "banner_\(placementId)",
            delegate: adDelegate,
            result: result
        )
    }

    private func requestAd(placementId: String?, adType: String?, position: String?, result: @escaping FlutterResult) {
        result(nil)
    }

    private func removeAdCallback(placementId: String?, result: @escaping FlutterResult) {
        if let placementId = placementId {
            adDelegates.removeValue(forKey: "image_\(placementId)")
            adDelegates.removeValue(forKey: "video_\(placementId)")
            adDelegates.removeValue(forKey: "native_\(placementId)")
            adDelegates.removeValue(forKey: "banner_\(placementId)")
        }
        result(nil)
    }

    private func requestConsentInfoUpdate(result: @escaping FlutterResult) {
        result("ok")
    }

    private func showConsentForm(result: @escaping FlutterResult) {
        result("ok")
    }

    private func getSKAdNetworkIds(result: @escaping FlutterResult) {
        do {
            let skAdNetworkIds = BidscubeSDK.getSKAdNetworkIDs()
            result(skAdNetworkIds)
        } catch {
            result(FlutterError(code: "SKADNETWORK_ERROR", message: "Failed to get SKAdNetwork IDs: \(error.localizedDescription)", details: nil))
        }
    }
}

// MARK: - Flutter View Factory
class NativeAdViewFactory: NSObject, FlutterPlatformViewFactory {
    private let adView: UIView

    init(adView: UIView) {
        self.adView = adView
    }

    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        return NativeAdPlatformView(adView: adView, frame: frame)
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}

// MARK: - Flutter Platform View
class NativeAdPlatformView: NSObject, FlutterPlatformView {
    private let adView: UIView
    private let frame: CGRect

    init(adView: UIView, frame: CGRect) {
        self.adView = adView
        self.frame = frame
    }

    func view() -> UIView {
        adView.frame = frame
        return adView
    }
}

// MARK: - Flutter Ad Delegate
class FlutterAdDelegate: NSObject, AdCallback {
    private weak var channel: FlutterMethodChannel?

    init(channel: FlutterMethodChannel?) {
        self.channel = channel
    }

    private func push(_ method: String, _ arguments: [String: Any]) {
        DispatchQueue.main.async { [weak self] in
            self?.channel?.invokeMethod(method, arguments: arguments)
        }
    }

    func onAdLoading(_ placementId: String) {
        push("onAdLoading", ["placementId": placementId])
    }

    func onAdLoaded(_ placementId: String) {
        push("onAdLoaded", ["placementId": placementId])
    }

    func onAdDisplayed(_ placementId: String) {
        push("onAdDisplayed", ["placementId": placementId])
    }

    func onAdFailed(_ placementId: String, errorCode: Int, errorMessage: String) {
        push("onAdFailed", [
            "placementId": placementId,
            "errorCode": String(errorCode),
            "errorMessage": errorMessage,
        ])
    }

    func onAdClicked(_ placementId: String) {
        push("onAdClicked", ["placementId": placementId])
    }

    func onAdClosed(_ placementId: String) {
        push("onAdClosed", ["placementId": placementId])
    }

    func onVideoAdStarted(_ placementId: String) {
        push("onVideoAdStarted", ["placementId": placementId])
    }

    func onVideoAdCompleted(_ placementId: String) {
        push("onVideoAdCompleted", ["placementId": placementId])
    }

    func onVideoAdSkipped(_ placementId: String) {
        push("onVideoAdSkipped", ["placementId": placementId])
    }
}
