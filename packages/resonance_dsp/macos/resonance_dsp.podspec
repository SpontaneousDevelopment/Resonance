#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint resonance_dsp.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'resonance_dsp'
  s.version          = '0.0.1'
  s.summary          = 'Real-time voice analysis primitives for Resonance.'
  s.description      = <<-DESC
Pitch (YIN), level, voicing and plosive detection over raw audio frames.
                       DESC
  s.homepage         = 'https://github.com/resonance-app/resonance'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Resonance' => 'joshuaglass1999@gmail.com' }

  # This will ensure the source files in Classes/ are included in the native
  # builds of apps using this FFI plugin. Podspec does not support relative
  # paths, so Classes contains a forwarder C file that relatively imports
  # `../src/*` so that the C sources can be shared among all target platforms.
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'

  # If your plugin requires a privacy manifest, for example if it collects user
  # data, update the PrivacyInfo.xcprivacy file to describe your plugin's
  # privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'resonance_dsp_privacy' => ['resonance_dsp/Sources/resonance_dsp/PrivacyInfo.xcprivacy']}

  s.dependency 'FlutterMacOS'

  s.platform = :osx, '10.11'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
