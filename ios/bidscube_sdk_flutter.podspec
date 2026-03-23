#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint bidscube_sdk_flutter.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'bidscube_sdk_flutter'
  s.version          = "1.0.0"
  s.summary          = 'BidsCube Flutter plugin: AppLovin MAX mediation + direct ad widgets on Android/iOS.'
  s.description      = <<-DESC
Flutter plugin bridging to native BidscubeSDK for AppLovin MAX mediation adapters
and for direct banner, video, and native ad widgets via PlatformViews.
                       DESC
  s.homepage         = 'https://github.com/bidscube/bidscube-sdk-flutter'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'BidsCube' => 'support@bidscube.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.dependency 'bidscubeSdk', '1.0.0'
  s.platform = :ios, '14.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end

