# iOS — vendored Bidscube SDK (optional)

For a **fully self-contained** build without the public `bidscubeSdk` CocoaPod, copy your Bidscube **`*.xcframework`** into this folder (any name, e.g. `BidscubeSDK.xcframework`).

The [`bidscube_sdk_flutter.podspec`](../bidscube_sdk_flutter.podspec) vendors **every** `Frameworks/*.xcframework` it finds. If the folder has no xcframeworks, the pod falls back to the `bidscubeSdk` CocoaPod from your Pod source.

**AppLovin MAX 13.x** is declared as a separate pod dependency (`AppLovinSDK`, `~> 13.0`) so mediation adapters compile against the correct SDK line.
