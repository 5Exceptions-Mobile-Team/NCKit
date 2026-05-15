Pod::Spec.new do |s|
  s.name             = "NCKit"
  s.version          = "1.0.0"
  s.summary          = "Noise cancellation framework for iOS."
  s.description      = "NCKit provides on-device noise cancellation for iOS applications (DeepFilterNet3 / libdf)."

  s.homepage         = "https://github.com/AyushBharadwaj/DFN3KIT"
  s.license          = {
    :type => "Proprietary",
    :text => "Copyright © 2026 5Exceptions. All rights reserved."
  }

  s.author           = {
    "5Exceptions Software Solutions" => "https://www.5exceptions.com",
    "Ayush Bharadwaj" => "ayush.bharadwaj@5exceptions.com"
  }

  s.platform         = :ios, "16.0"
  s.swift_version    = "5.9"
  s.requires_arc     = true

  s.source           = {
    :git => "https://github.com/AyushBharadwaj/DFN3KIT.git",
    :tag => s.version.to_s
  }

  s.vendored_frameworks = "NCKit.xcframework"
  s.frameworks       = "AVFoundation", "Accelerate"
end
