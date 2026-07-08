# iOS — vendored Bidscube SDK (optional)

For a **fully self-contained** build without the public `BidscubeSDKAppLovin` CocoaPod, copy your Bidscube **`*.xcframework`** into this folder.

The [`bidscube_sdk_flutter.podspec`](../bidscube_sdk_flutter.podspec) vendors **every** `Frameworks/*.xcframework` it finds. If the folder has no xcframeworks, the pod depends on **`BidscubeSDKAppLovin ~> 1.1.0`**, which includes:

- Bidscube runtime sources  
- **`ALBidscubeMediationAdapter`** for AppLovin MAX  
- Transitive **`AppLovinSDK`** 13.x and Google IMA  

**Important:** vendored runtime-only XCFrameworks typically do **not** ship `ALBidscubeMediationAdapter`. For AppLovin MAX mediation QA, prefer the **`BidscubeSDKAppLovin`** pod (no vendored frameworks).
