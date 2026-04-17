#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint bidscube_sdk_flutter.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'bidscube_sdk_flutter'
  s.version          = '1.0.3+1'
  s.summary          = 'BidsCube Flutter plugin: AppLovin MAX 13+ mediation + direct ad widgets on Android/iOS.'
  s.description      = <<-DESC
Flutter plugin bridging to native BidscubeSDK for AppLovin MAX mediation adapters
and for direct banner, video, and native ad widgets via PlatformViews.
Supports vendored Bidscube XCFramework under ios/Frameworks for self-contained builds.
                       DESC
  s.homepage         = 'https://github.com/bidscube/bidscube-sdk-flutter'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'BidsCube' => 'support@bidscube.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.dependency 'AppLovinSDK', '~> 13.0'
  s.platform = :ios, '13.0'

  frameworks_dir = File.expand_path('Frameworks', __dir__)
  vendored_xcs = Dir[File.join(frameworks_dir, '*.xcframework')]
  if vendored_xcs.any?
    s.vendored_frameworks = vendored_xcs.map { |abs| 'Frameworks/' + File.basename(abs) }
  else
    s.dependency 'bidscubeSdk', '1.0.0'
  end

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
