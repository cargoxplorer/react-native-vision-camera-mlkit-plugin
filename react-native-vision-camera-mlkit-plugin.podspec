require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

Pod::Spec.new do |s|
  s.name         = "react-native-vision-camera-mlkit-plugin"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.homepage     = package["homepage"]
  s.license      = package["license"]
  s.authors      = package["author"]

  s.platforms    = { :ios => "15.5" }
  s.source       = { :git => package["repository"]["url"], :tag => "#{s.version}" }

  s.source_files = "ios/**/*.{h,m,swift}"

  # Swift support
  s.swift_version = '5.0'

  # React Native dependencies
  s.dependency "React-Core"

  # Vision Camera dependencies
  s.dependency "VisionCamera"
  s.dependency "react-native-worklets-core"

  # Google ML Kit dependencies
  s.dependency "GoogleMLKit/TextRecognition", '>= 8.0.0'
  s.dependency "GoogleMLKit/TextRecognitionChinese", '>= 8.0.0'
  s.dependency "GoogleMLKit/TextRecognitionDevanagari", '>= 8.0.0'
  s.dependency "GoogleMLKit/TextRecognitionJapanese", '>= 8.0.0'
  s.dependency "GoogleMLKit/TextRecognitionKorean", '>= 8.0.0'
  s.dependency "GoogleMLKit/BarcodeScanning", '>= 7.0.0'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'SWIFT_VERSION' => '5.0'
  }
end
