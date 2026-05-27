# NCKit

On-device noise cancellation for iOS. No network, no server — processing stays on the device.

## Requirements

| | |
|-|-|
| iOS | 16.0+ |
| Xcode | 15+ |
| Swift | 5.9+ |
| Arch | arm64 device, arm64 simulator (Apple Silicon Mac) |

## Install

### Swift Package Manager

Xcode → **File → Add Package Dependencies…**

```
https://github.com/5Exceptions-Mobile-Team/NCKit.git
```

Version: **1.0.1** (or latest tag).

Add **NCKit** to your app target and set **Embed & Sign**.

`Package.swift`:

```swift
.package(url: "https://github.com/5Exceptions-Mobile-Team/NCKit.git", from: "1.1.1")
```

### CocoaPods

```ruby
pod 'NCKit', '~> 1.1.1'
```

### Manual

Download `NCKit.xcframework` from [Releases](https://github.com/5Exceptions-Mobile-Team/NCKit/releases), drag into Xcode, **Embed & Sign**.

## Quick start

```swift
import NCKit

let modelURL = try NCKitModelLocator.modelTarGzURL()
let processor = try NCKitProcessor(modelURL: modelURL)

try NCKitFileProcessor.processFile(
    inputURL: inputURL,
    outputURL: outputURL,
    processor: processor
)
```

Real-time mic: create one `NCKitProcessor`, call `processFrame` with `frameLength` samples at 48 kHz. See the sample app and docs for `AVAudioEngine` setup.

## Public API

| Type | Role |
|------|------|
| `NCKitModelLocator` | Resolve bundled model path |
| `NCKitProcessor` | Real-time frame processing |
| `NCKitFileProcessor` | Offline file denoise |
| `NCKitAudioNormalizer` | Optional loudness normalization |
| `NCKitError` | Typed errors |

## Sample app

```bash
git clone https://github.com/5Exceptions-Mobile-Team/NCKit_Demo.git
cd NCKit_Demo
open NCKitSample.xcodeproj
```

## License

Proprietary. See [LICENSE](LICENSE).
