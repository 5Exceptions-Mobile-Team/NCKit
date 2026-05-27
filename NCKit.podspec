Pod::Spec.new do |s|
  s.name             = "NCKit"
  s.version          = "1.1.1"
  s.summary          = "Noise cancellation framework for iOS."
  s.description      = "NCKit provides on-device noise cancellation for iOS applications (DeepFilterNet3 / libdf)."

  s.homepage         = "https://github.com/5Exceptions-Mobile-Team/NCKit"
  s.license          = {
    :type => "Proprietary",
    :text => "Copyright © 2026 NCKit. All rights reserved."
  }

  s.author           = { "NCKit" => "https://docs.nckit.io" }

  s.platform         = :ios, "16.0"
  s.swift_version    = "5.9"
  s.requires_arc     = true

  s.source           = {
    :git => "https://github.com/5Exceptions-Mobile-Team/NCKit.git",
    :tag => s.version.to_s
  }

  s.vendored_frameworks = "NCKit.xcframework"
  s.frameworks       = "AVFoundation", "Accelerate"
end
