# NCKit — iOS distribution package

Drop-in **NCKit.xcframework** for on-device noise cancellation (DeepFilterNet3 / libdf). Integrate via **Swift Package Manager**, **CocoaPods**, or by dragging the xcframework into Xcode.

**Repository:** [github.com/AyushBharadwaj/DFN3KIT](https://github.com/AyushBharadwaj/DFN3KIT)  
**Author:** 5Exceptions Software Solutions · Ayush Bharadwaj

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
    .package(url: "https://github.com/AyushBharadwaj/DFN3KIT.git", from: "1.0.0")
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
pod 'NCKit', :git => 'https://github.com/AyushBharadwaj/DFN3KIT.git', :tag => '1.0.0'
```

Then:

```bash
pod install
```

## Manual Xcode integration

1. Drag `NCKit.xcframework` into your project.
2. Target → **General** → **Frameworks, Libraries, and Embedded Content** → **Embed & Sign**.
3. `import NCKit`

## Public API (summary)

| Type | Use |
|------|-----|
| `LibDFProcessor` | Real-time / streaming: 480-sample hops @ 48 kHz |
| `DFN3FileProcessor` | Offline: audio/video file → denoised WAV |
| `DFN3ModelLocator` | Resolve embedded `DeepFilterNet3_onnx.tar.gz` |
| `DFN3AudioNormalizer` | Optional speech-gated level matching |
| `DFN3Error` | Errors |

Full API and usage examples: see `NCKit/README.md` in the main repo (SDK source tree).

## Rebuilding the xcframework

From the main **Krispy** repo root:

```bash
./scripts/build_dfn3kit_xcframework.sh
cp -R NCKit/NCKit.xcframework NCKit-iOS/
```

## License

- **libdf / DeepFilterNet3 model**: Apache 2.0 / MIT per [DeepFilterNet](https://github.com/Rikorose/DeepFilterNet).
- **NCKit Swift wrapper & packaging**: use per your project’s distribution terms.
