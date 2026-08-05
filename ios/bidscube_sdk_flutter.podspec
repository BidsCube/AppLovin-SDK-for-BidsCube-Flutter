#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint bidscube_sdk_flutter.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'bidscube_sdk_flutter'
  s.version          = "1.2.5"
  s.summary          = 'BidsCube Flutter plugin: AppLovin MAX 13+ mediation + direct ad widgets on Android/iOS.'
  s.description      = <<-DESC
Flutter plugin bridging to native BidscubeSDK for AppLovin MAX mediation adapters
and for direct banner, video, and native ad widgets via PlatformViews.
Pulls BidscubeSDKAppLovin (runtime + ALBidscubeMediationAdapter) or optional vendored XCFrameworks.
                       DESC
  s.homepage         = 'https://github.com/bidscube/bidscube-sdk-flutter'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'BidsCube' => 'support@bidscube.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '15.0'

  frameworks_dir = File.expand_path('Frameworks', __dir__)
  vendored_xcs = Dir[File.join(frameworks_dir, '*.xcframework')]
  if vendored_xcs.any?
    s.vendored_frameworks = vendored_xcs.map { |abs| 'Frameworks/' + File.basename(abs) }
    # Vendored runtime-only XCFrameworks do not include ALBidscubeMediationAdapter.
    # For MAX mediation QA, prefer the BidscubeSDKAppLovin pod (no vendored frameworks).
    s.dependency 'AppLovinSDK', '>= 13.0.0', '< 14.0'
  else
    s.dependency 'BidscubeSDKAppLovin', '~> 1.1.0'
  end

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
