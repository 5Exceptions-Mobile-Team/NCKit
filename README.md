# NCKit — iOS distribution package

Drop-in **NCKit.xcframework** for on-device noise cancellation (DeepFilterNet3 / libdf). Integrate via **Swift Package Manager**, **CocoaPods**, or by dragging the xcframework into Xcode.

**Repository:** [github.com/5Exceptions-Mobile-Team/NCKit](https://github.com/5Exceptions-Mobile-Team/NCKit)  
**Author:** 5Exceptions Software Solutions 

## Contents

```
NCKit-iOS/
├── Package.swift           # Swift Package Manager
├── NCKit.podspec           # CocoaPods
├── NCKit.xcframework       # Prebuilt binary (device + Apple Silicon simulator)
└── README.md
```

## Requirements

- iOS **16.0+**
- Xcode **15+**
- Apple Silicon Mac for simulator (arm64-simulator slice only)

## Swift Package Manager

### Local path (this folder)

In Xcode: **File → Add Package Dependencies… → Add Local…** and select this `NCKit-iOS` directory.

Or add to your root `Package.swift`:

```swift
dependencies: [
    .package(path: "../NCKit-iOS")
],
targets: [
    .target(
        name: "YourApp",
        dependencies: ["NCKit"]
    )
]
```

### Git URL

```swift
dependencies: [
    .package(url: "https://github.com/5Exceptions-Mobile-Team/NCKit.git", from: "1.0.0")
]
```

Then in your app target: **Frameworks, Libraries, and Embedded Content** → ensure **NCKit** is embedded (**Embed & Sign** for app targets).

```swift
import NCKit

let processor = try LibDFProcessor(modelURL: DFN3ModelLocator.modelTarGzURL())
```

## CocoaPods

Add to your `Podfile`:

```ruby
pod 'NCKit', :path => '../NCKit-iOS'
```

Or from GitHub:

```ruby
pod 'NCKit', :git => 'https://<Token>@github.com/5Exceptions-Mobile-Team/NCKit.git', :tag => '1.0.0'
```

Then:

```bash
pod install
```
