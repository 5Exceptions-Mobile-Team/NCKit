<div align="center">

<img src="https://raw.githubusercontent.com/5Exceptions-Mobile-Team/NCKit/main/.github/assets/nckit-logo.png"
     alt="NCKit" width="110" height="110"/>

# NCKit

### Enterprise On-Device Noise Cancellation SDK for iOS
### Powered by NCKit

[![Platform](https://img.shields.io/badge/platform-iOS%2016%2B-0A84FF.svg?style=flat-square&logo=apple)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.9%2B-FA7343.svg?style=flat-square&logo=swift)](https://swift.org)
[![SPM](https://img.shields.io/badge/SPM-compatible-34C759.svg?style=flat-square)](https://swift.org/package-manager/)
[![CocoaPods](https://img.shields.io/cocoapods/v/NCKit.svg?style=flat-square&color=EE3322)](https://cocoapods.org/pods/NCKit)
[![License](https://img.shields.io/badge/license-Proprietary-8E8E93.svg?style=flat-square)](LICENSE)
[![Arch](https://img.shields.io/badge/arch-arm64%20%7C%20arm64--sim-5E5CE6.svg?style=flat-square)](https://developer.apple.com/documentation/xcode/building-a-universal-macos-binary)

**Production-grade noise suppression. 100% on-device. Zero cloud dependency.**

[Quick Start](#quick-start) •
[API Reference](#api-reference) •
[Architecture](#architecture) •
[Sample App](https://github.com/5Exceptions-Mobile-Team/NCKit_Demo) •
[Changelog](#changelog) •
[Support](#support)

</div>

---

## Overview

NCKit is an enterprise iOS SDK that brings **NCKit-powered real-time noise cancellation** to your iOS applications — both live-stream and offline file processing. The entire audio pipeline runs entirely on-device using a bundled ONNX model, with no network calls, no privacy trade-offs, and no server infrastructure required.

### What NCKit Solves

| Scenario | Without NCKit | With NCKit |
|----------|--------------|------------|
| Field recordings (outdoor, HVAC, crowd) | Unintelligible audio | Clear speech, ~20 dB noise reduction |
| In-vehicle voice capture | Road noise dominates | Voice isolated, noise floor near silence |
| Remote collaboration in open offices | Keyboard, HVAC bleed | Professional call quality |
| Audio/video post-production | Manual noise reduction in DAW | Automated, one-pass clean audio |

---

## Features

| Feature | Details |
|---------|---------|
| **NCKit Engine** | State-of-the-art neural noise suppression via bundled `NCKit_model.tar.gz` |
| **Offline File Processing** | Denoise any file AVFoundation can read — MP4, M4A, WAV, MOV, MP3, and more |
| **Real-Time Frame Processing** | Low-level `processFrame` API for custom live-stream pipelines |
| **Automatic Resampling** | Any input sample rate → 48 kHz mono, handled transparently |
| **Speech-Gated Normalization** | Post-denoise makeup gain with soft tanh limiter — level-consistent output |
| **Chunked I/O** | Streaming file I/O, never loads the full audio into memory — safe on-device for long clips |
| **Full Type Safety** | Typed `NCKitError` enum with structured cases — no stringly-typed failures |
| **Sendable Errors** | `NCKitError` is `Sendable` — safe in Swift Concurrency / `async`-`await` contexts |
| **On-Device Privacy** | Audio never leaves the device — GDPR, HIPAA, and enterprise compliance friendly |

---

## Requirements

| | Minimum |
|-|---------|
| **iOS** | 16.0 |
| **Xcode** | 15.0 |
| **Swift** | 5.9 |
| **Architecture** | `arm64` (device), `arm64` (Apple Silicon simulator) |

> **Note:** x86_64 (Intel Mac) simulator is **not supported**. Use Rosetta (`arm64`) or a physical device.

---

## Installation

### Swift Package Manager

#### Option A — Remote (GitHub)

Add to your `Package.swift`:

```swift
dependencies: [
    .package(
        url: "https://github.com/5Exceptions-Mobile-Team/NCKit.git",
        from: "1.0.0"
    )
],
targets: [
    .target(
        name: "YourApp",
        dependencies: ["NCKit"]
    )
]
```

Or in Xcode: **File → Add Package Dependencies…** and enter:

```
https://github.com/5Exceptions-Mobile-Team/NCKit.git
```

#### Option B — Local Path

```swift
dependencies: [
    .package(path: "../NCKit-iOS")
]
```

> After adding the package, go to your app target → **Frameworks, Libraries, and Embedded Content** → set **NCKit** to **Embed & Sign**.

### CocoaPods

```ruby
# Podfile

# From GitHub (private)
pod 'NCKit', :git => 'https://<TOKEN>@github.com/5Exceptions-Mobile-Team/NCKit.git', :tag => '1.0.0'

# Or local path during development
pod 'NCKit', :path => '../NCKit-iOS'
```

```bash
pod install
open YourApp.xcworkspace
```

### Manual — XCFramework

1. Download `NCKit.xcframework` from [Releases](https://github.com/5Exceptions-Mobile-Team/NCKit/releases)
2. Drag it into your Xcode project
3. In target settings → **Frameworks, Libraries, and Embedded Content** → set to **Embed & Sign**
4. Link `AVFoundation` and `Accelerate` if not already linked

---

## Quick Start

### Offline File Denoising

The most common use case — denoise a recorded audio or video file:

```swift
import NCKit

func denoiseRecording(inputURL: URL, outputURL: URL) async throws {
    // 1. Locate the bundled NCKit model
    let modelURL = try NCKitModelLocator.modelTarGzURL()

    // 2. Create the processor (loads model once — reuse across calls)
    let processor = try NCKitProcessor(
        modelURL: modelURL,
        attenLimDb: 100,          // 100 = unlimited attenuation (recommended)
        postFilterBeta: 0         // 0 = disabled (enable with 0.05 for extra suppression)
    )

    // 3. Process the file — streams I/O, safe for long clips
    try NCKitFileProcessor.processFile(
        inputURL: inputURL,
        outputURL: outputURL,
        processor: processor
    )

    // 4. (Optional) Normalize output volume
    var samples = try loadSamples(from: outputURL)   // your WAV loader
    NCKitAudioNormalizer.applySpeechGatedMakeupGain(
        &samples,
        sampleRate: 48_000,
        targetRmsDbfs: -18   // -18 dBFS target loudness
    )
}
```

### Real-Time Frame Processing

For live microphone → speaker pipelines using `AVAudioEngine`:

```swift
import NCKit
import AVFoundation

final class RealtimeDenoiser {
    private let processor: NCKitProcessor
    private let engine = AVAudioEngine()

    init() throws {
        let modelURL = try NCKitModelLocator.modelTarGzURL()
        processor = try NCKitProcessor(modelURL: modelURL, attenLimDb: 100)
    }

    func start() throws {
        let inputNode = engine.inputNode
        let frameLength = processor.frameLength  // typically 480 samples @ 48kHz

        // Use the exact format libdf expects: Float32, 48 kHz, mono
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 48_000,
            channels: 1,
            interleaved: false
        ) else { throw NCKitError.unsupportedFormat }

        // Pre-allocate output buffer — never allocate in the render callback
        var outputBuffer = [Float](repeating: 0, count: frameLength)

        inputNode.installTap(
            onBus: 0,
            bufferSize: AVAudioFrameCount(frameLength),
            format: format
        ) { [weak self] buffer, _ in
            guard let self,
                  let inputData = buffer.floatChannelData?[0] else { return }

            outputBuffer.withUnsafeMutableBufferPointer { outPtr in
                guard let outBase = outPtr.baseAddress else { return }
                self.processor.processFrame(input: inputData, output: outBase)
            }
            // Route outputBuffer to your player node or network stream here
        }

        try engine.start()
    }

    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
    }
}
```

### SwiftUI Integration

```swift
import SwiftUI
import NCKit

struct DenoiseView: View {
    @StateObject private var vm = DenoiseViewModel()

    var body: some View {
        VStack(spacing: 24) {
            Text(vm.statusMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)

            if vm.isProcessing {
                ProgressView(value: vm.progress)
                    .progressViewStyle(.linear)
                    .padding(.horizontal)
            }

            Button(action: vm.pickAndDenoise) {
                Label("Select & Denoise File", systemImage: "waveform.badge.magnifyingglass")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(vm.isProcessing)
        }
        .padding()
        .alert("Error", isPresented: $vm.showError) {
            Button("OK") {}
        } message: {
            Text(vm.errorMessage)
        }
    }
}

@MainActor
final class DenoiseViewModel: ObservableObject {
    @Published var statusMessage = "Select a file to begin"
    @Published var isProcessing = false
    @Published var progress: Double = 0
    @Published var showError = false
    @Published var errorMessage = ""

    private var processor: NCKitProcessor?

    func pickAndDenoise() {
        // Load the processor once and reuse
        if processor == nil {
            do {
                let modelURL = try NCKitModelLocator.modelTarGzURL()
                processor = try NCKitProcessor(modelURL: modelURL)
            } catch {
                showError(error)
                return
            }
        }
        // Present file picker, then call processFile on a background task
    }

    private func showError(_ error: Error) {
        errorMessage = errorDescription(error)
        showError = true
    }

    private func errorDescription(_ error: Error) -> String {
        switch error as? NCKitError {
        case .missingModel(let name):
            return "Model file not found: \(name). Reinstall the app."
        case .libraryInit:
            return "Failed to initialize the DeepFilter engine. Check model integrity."
        case .unsupportedFormat:
            return "This file format is not supported."
        case .resampleFailed:
            return "Could not convert audio to 48 kHz. Try a different file."
        case .cannotOpenInput:
            return "Cannot read the selected file. Check file permissions."
        case .cannotCreateOutput:
            return "Cannot write the output file. Check available storage."
        case .badFrameLength(let n):
            return "Unexpected frame length: \(n). Please report this issue."
        case nil:
            return error.localizedDescription
        }
    }
}
```

---

## API Reference

### `NCKitProcessor`

The core NCKit inference engine. Wraps the libdf C runtime. Create once, reuse across frames.

```swift
public final class NCKitProcessor {

    /// Number of Float32 samples expected per processFrame call.
    /// Always 480 at 48 kHz (10ms per frame).
    public let frameLength: Int

    /// Initialize the processor and load the NCKit model.
    ///
    /// - Parameters:
    ///   - modelURL: Path to `NCKit_model.tar.gz`. Use `NCKitModelLocator.modelTarGzURL()`.
    ///   - attenLimDb: Maximum noise attenuation in dB. `100` = unlimited (recommended).
    ///                 Lower values (e.g. `20`) preserve some background for naturalness.
    ///   - postFilterBeta: Post-filter strength. `0` = disabled. Range `0.0...0.05`.
    ///                     A value of `0.05` adds extra suppression on top of the neural model.
    /// - Throws: `NCKitError.libraryInit` if the model cannot be loaded.
    public init(modelURL: URL, attenLimDb: Float = 100, postFilterBeta: Float = 0) throws

    /// Process exactly `frameLength` samples of mono Float32 audio.
    ///
    /// **Must be called with exactly `frameLength` samples.** Output is written to `output`.
    /// Both pointers must point to at least `frameLength` Float32 values.
    ///
    /// - Returns: Local SNR estimate for this frame in dB. Can be used to gate processing.
    @discardableResult
    public func processFrame(
        input: UnsafeMutablePointer<Float>,
        output: UnsafeMutablePointer<Float>
    ) -> Float

    /// Update attenuation limit at runtime (no model reload required).
    public func setAttenLim(_ db: Float)

    /// Update post-filter strength at runtime.
    public func setPostFilterBeta(_ b: Float)
}
```

---

### `NCKitFileProcessor`

Offline file denoise pipeline. Reads any AVFoundation-compatible format, resamples to 48 kHz mono, runs libdf, writes 16-bit PCM WAV. Streaming I/O — safe for clips of any length.

```swift
public enum NCKitFileProcessor {

    /// Output sample rate: always 48,000 Hz.
    public static let targetSampleRate: Double  // 48_000

    /// Denoise an audio or video file.
    ///
    /// Supported inputs: WAV, M4A, MP4, MOV, MP3, AIFF, CAF, and any format AVFoundation decodes.
    /// Output: 16-bit PCM WAV at 48 kHz mono.
    ///
    /// - Parameters:
    ///   - inputURL: Source file URL.
    ///   - outputURL: Destination WAV file URL. Created (or overwritten) by this method.
    ///   - processor: A `NCKitProcessor` instance. Reuse across calls for performance.
    /// - Throws: `NCKitError`
    public static func processFile(
        inputURL: URL,
        outputURL: URL,
        processor: NCKitProcessor
    ) throws
}
```

**Supported Input Formats:** WAV · M4A · MP4 · MOV · MP3 · AIFF · CAF · any format `AVAudioFile` can open.

**Output Format:** 16-bit PCM WAV · 48 kHz · Mono.

---

### `NCKitModelLocator`

Locates and materializes the bundled `NCKit_model.tar.gz` model to a writable filesystem path that `NCKitProcessor` can open.

```swift
public enum NCKitModelLocator {

    /// The bundle to search. Automatically resolves to `Bundle.module` for SPM builds
    /// and `Bundle(for: NCKitProcessor.self)` for framework builds.
    public static var defaultBundle: Bundle { get }

    /// Copy the model tarball to the temporary directory (once per launch) and return its URL.
    ///
    /// Safe to call multiple times — skips the copy if the destination already exists.
    /// Falls back to `Bundle.main` if the model is embedded in the app target rather than the framework.
    ///
    /// - Throws: `NCKitError.missingModel` if the tarball cannot be found in any bundle.
    public static func modelTarGzURL(bundle: Bundle = defaultBundle) throws -> URL
}
```

---

### `NCKitAudioNormalizer`

Post-denoise normalization. Applies a single static makeup gain over speech-active windows and soft-limits peaks with a tanh limiter — no pumping artifacts.

```swift
public enum NCKitAudioNormalizer {

    /// Normalize denoised mono audio to a target loudness.
    ///
    /// - Parameters:
    ///   - samples: Mono Float32 samples at `sampleRate`. Modified in place.
    ///   - sampleRate: Samples per second (typically `48_000`).
    ///   - targetRmsDbfs: Target RMS loudness for speech-active segments. Default `-18` dBFS.
    ///   - maxGainDb: Maximum makeup gain cap (prevents boosting near-silent clips). Default `15` dB.
    ///   - peakCeilingDbfs: Soft-limiter ceiling. Default `-1.0` dBFS (safe for encoded delivery).
    public static func applySpeechGatedMakeupGain(
        _ samples: inout [Float],
        sampleRate: Int,
        targetRmsDbfs: Float = -18,
        maxGainDb: Float = 15,
        peakCeilingDbfs: Float = -1
    )

    /// Apply tanh soft-limiting without any gain change.
    ///
    /// Below the knee (70% of ceiling), signal is unchanged.
    /// Above the knee, amplitude is shaped smoothly toward `peakCeilingDbfs`.
    public static func softLimitInPlace(
        _ samples: inout [Float],
        peakCeilingDbfs: Float = -1
    )
}
```

---

### `NCKitError`

Typed error domain. All NCKit-throwing methods throw `NCKitError`.

```swift
public enum NCKitError: Error, Sendable {
    /// Model tarball not found in any bundle. `String` is the expected filename.
    case missingModel(String)

    /// `df_create()` returned nil — model file is corrupt or incompatible.
    case libraryInit

    /// Caller provided a buffer whose length doesn't match `NCKitProcessor.frameLength`.
    case badFrameLength(Int)

    /// `AVAudioFile` could not open the input file.
    case cannotOpenInput

    /// Output WAV file could not be created (permissions, disk full).
    case cannotCreateOutput

    /// Input format is not Float32 and could not be converted, or the file has no audio track.
    case unsupportedFormat

    /// `AVAudioConverter` failed to resample to 48 kHz.
    case resampleFailed
}
```

---

## Architecture

```
NCKit SDK Architecture
─────────────────────────────────────────────────────────────────────

  ┌──────────────────────────────────────────────────────────────┐
  │                        Your Application                       │
  └────────────┬─────────────────────┬────────────────────────────┘
               │                     │
       Offline Files           Live Audio Stream
               │                     │
               ▼                     ▼
  ┌─────────────────────┐  ┌─────────────────────────────┐
  │  NCKitFileProcessor  │  │   AVAudioEngine + installTap │
  │                     │  │   (your app code)            │
  │  • AVAudioFile read │  └────────────┬────────────────┘
  │  • AVAudioConverter │               │  480 Float32 samples
  │    (→ 48kHz mono)   │               │  per callback
  │  • Chunked I/O      │               │
  └────────┬────────────┘               │
           │ 480 samples/frame          │
           ▼                            ▼
  ┌─────────────────────────────────────────────────────┐
  │                   NCKitProcessor                     │
  │                                                      │
  │  processFrame(input:, output:) → SNR (dB)           │
  │                                                      │
  │  ┌─────────────────────────────────────────────┐    │
  │  │          DeepFilter.xcframework              │    │
  │  │          (libdf static library)              │    │
  │  │                                              │    │
  │  │  df_create → df_process_frame → df_free     │    │
  │  │                                              │    │
  │  │  Internals (all in Rust/C runtime):         │    │
  │  │    STFT → ERB Features → GRU DNN            │    │
  │  │    → ERB Gains → DF Coefs → iSTFT           │    │
  │  └─────────────────────────────────────────────┘    │
  │                                                      │
  │  Model: NCKit_model.tar.gz (bundled)        │
  └────────────────────────┬────────────────────────────┘
                           │
                           ▼
            ┌──────────────────────────┐
            │    NCKitAudioNormalizer   │   (optional post-step)
            │                          │
            │  Speech-gated RMS gain  │
            │  Tanh soft limiter      │
            └──────────────────────────┘
                           │
                           ▼
                  16-bit PCM WAV output
                  (48 kHz, mono)
```

### Audio Pipeline — Frame Processing Detail

```
Input frame (480 Float32 samples @ 48 kHz = 10ms)
    │
    ▼
df_process_frame()
    ├── STFT  →  Complex spectrum
    ├── ERB filterbank  →  Feature vector
    ├── GRU-based DNN  →  ERB gains + DF coefficients
    ├── Apply gains + DF filtering
    └── iSTFT  →  Clean output frame (480 Float32 samples)
    │
    ▼
Output frame (480 Float32 samples, noise suppressed)

Lookahead: 2 frames (20ms) — compensated automatically in NCKitFileProcessor
```

---

## Processing Parameters

### Attenuation Limit (`attenLimDb`)

Controls the maximum noise reduction ceiling.

| Value | Effect | Use When |
|-------|--------|----------|
| `100` | Unlimited (recommended) | Heavy noise environments |
| `40` | Moderate suppression | Light noise, preserve ambience |
| `20` | Gentle suppression | Podcasts, music with voice |
| `0` | Passthrough (debugging only) | Bypass validation |

### Post-Filter Beta (`postFilterBeta`)

Applies an additional suppression stage on top of the neural model.

| Value | Effect |
|-------|--------|
| `0` | Disabled (default — cleanest artifacts) |
| `0.02` | Subtle extra suppression |
| `0.05` | Maximum extra suppression |

> Start with `postFilterBeta: 0`. Enable only if residual noise remains after tuning `attenLimDb`.

### Speech Normalization (`targetRmsDbfs`)

| Value | Use Case |
|-------|----------|
| `-18` | Standard voice delivery (default) |
| `-16` | Punchy / broadcast voice |
| `-23` | Broadcast loudness standard (EBU R128 / ATSC A/85) |

---

## Best Practices

### Reuse `NCKitProcessor`

```swift
// Create once — model loading takes ~50–200ms
// Reusing across files saves significant time

final class DenoiseService {
    static let shared = DenoiseService()
    private var processor: NCKitProcessor?

    func getProcessor() throws -> NCKitProcessor {
        if let p = processor { return p }
        let modelURL = try NCKitModelLocator.modelTarGzURL()
        let p = try NCKitProcessor(modelURL: modelURL)
        processor = p
        return p
    }
}
```

### Offload File Processing to a Background Task

```swift
func denoiseAsync(input: URL, output: URL) async throws {
    let processor = try await Task.detached(priority: .userInitiated) {
        try DenoiseService.shared.getProcessor()
    }.value

    try await Task.detached(priority: .userInitiated) {
        try NCKitFileProcessor.processFile(
            inputURL: input,
            outputURL: output,
            processor: processor
        )
    }.value
}
```

### Real-Time Pipeline Safety

```swift
// In the installTap callback — NEVER allocate inside this closure
// Pre-allocate outputBuffer before calling installTap
var outputBuffer = [Float](repeating: 0, count: processor.frameLength)

inputNode.installTap(onBus: 0, bufferSize: frameCount, format: format) {
    [weak self] buffer, _ in
    guard let self else { return }
    // Safe — uses pre-allocated storage
    outputBuffer.withUnsafeMutableBufferPointer { out in
        guard let base = out.baseAddress,
              let input = buffer.floatChannelData?[0] else { return }
        self.processor.processFrame(input: input, output: base)
    }
}
```

### AVAudioSession Setup for Real-Time Use

```swift
func configureAudioSession() throws {
    let session = AVAudioSession.sharedInstance()
    // .voiceChat or .measurement work best with libdf's 48kHz expectation
    try session.setCategory(
        .playAndRecord,
        mode: .measurement,         // Disables built-in processing that conflicts with libdf
        options: [.allowBluetooth, .defaultToSpeaker]
    )
    try session.setPreferredSampleRate(48_000)
    try session.setPreferredIOBufferDuration(0.01)  // 10ms = 480 samples
    try session.setActive(true)
}
```

### Handle Audio Interruptions

```swift
NotificationCenter.default.addObserver(
    forName: AVAudioSession.interruptionNotification,
    object: nil,
    queue: .main
) { notification in
    guard let info = notification.userInfo,
          let type = info[AVAudioSessionInterruptionTypeKey] as? UInt,
          let interruptionType = AVAudioSession.InterruptionType(rawValue: type) else { return }

    switch interruptionType {
    case .began:
        engine.pause()
    case .ended:
        if let options = info[AVAudioSessionInterruptionOptionKey] as? UInt,
           AVAudioSession.InterruptionOptions(rawValue: options).contains(.shouldResume) {
            try? engine.start()
        }
    @unknown default: break
    }
}
```

---

## Troubleshooting

### `NCKitError.missingModel`

The model tarball `NCKit_model.tar.gz` is bundled inside `NCKit.xcframework`. If you get this error:

1. Confirm the framework is embedded as **Embed & Sign** (not just **Do Not Embed**)
2. In SPM: verify `NCKit` appears in **Frameworks, Libraries, and Embedded Content**
3. In CocoaPods: run `pod install --repo-update` and clean build folder (`Cmd+Shift+K`)

### `NCKitError.libraryInit`

The model file exists but `libdf` could not load it:

- Ensure you are running on an **arm64** device or Apple Silicon Mac simulator
- x86_64 (Intel Mac) simulator is not supported — use Rosetta or a physical device
- Try deleting the derived data folder and rebuilding

### Intel Mac Simulator Crash

```
Assertion failed: arch not in xcframework slices
```

NCKit ships `arm64-simulator` only. On an Intel Mac, either:
- Enable Rosetta: **Product → Destination → Rosetta Simulator**
- Or test on a physical device

### High Memory Usage During File Processing

`NCKitFileProcessor` uses streaming I/O with an 8192-frame read chunk. Memory usage stays constant regardless of file length. If memory grows unexpectedly:
- Ensure you are not accumulating the output samples in memory (write to a file, not an array)
- Use `autoreleasepool` wrappers around processing loops in Objective-C mixed projects

### Output Audio Is Silent

- Verify input file has an audio track: `AVAsset(url: inputURL).tracks(withMediaType: .audio)`
- Confirm `inputURL` is file-scheme (not a remote URL)
- Check `NCKitError.unsupportedFormat` — the file may have an unusual codec

### Clicks / Artifacts at File Boundaries

The libdf runtime has a 2-frame lookahead (20ms). `NCKitFileProcessor` compensates this automatically by flushing extra silent frames and trimming the output to match the input duration. If you are calling `processFrame` manually, skip the first `processor.frameLength * 2` output samples.

---

## Sample App

The **[NCKit Demo](https://github.com/5Exceptions-Mobile-Team/NCKit_Demo)** demonstrates real-world integration:

- File picker → denoise → export to Files.app
- Real-time microphone noise cancellation with level meter
- Before/after audio comparison player
- Performance metrics (processing time per file, frame SNR)
- SwiftUI and UIKit integration examples

```bash
git clone https://github.com/5Exceptions-Mobile-Team/NCKit_Demo.git
cd NCKit_Demo
open NCKitDemo.xcodeproj
```

> Requires a **physical iOS device** or **Apple Silicon Mac** for noise cancellation.
> Intel Mac simulator will build but NC is disabled.

---

## Changelog

### v1.0.0
- Initial release
- `NCKitProcessor` — NCKit frame-by-frame inference
- `NCKitFileProcessor` — Offline file denoise with streaming I/O
- `NCKitModelLocator` — Bundle-aware model discovery
- `NCKitAudioNormalizer` — Speech-gated makeup gain + tanh limiter
- XCFramework: `ios-arm64` (device) + `ios-arm64-simulator` (Apple Silicon)
- SPM + CocoaPods distribution

---

## License

NCKit is proprietary software. © 2026 5Exceptions Software Solutions. All rights reserved.

See [LICENSE](LICENSE) for the full license terms.

---

## Support

| Channel | Details |
|---------|---------|
| **Email** | [sdk@5exceptions.com](mailto:sdk@5exceptions.com) |
| **Bug Reports** | [GitHub Issues](https://github.com/5Exceptions-Mobile-Team/NCKit/issues) |
| **Enterprise Support** | Contact [sdk@5exceptions.com](mailto:sdk@5exceptions.com) for SLA-backed support plans |
| **Website** | [5exceptions.com](https://5exceptions.com) |

---

<div align="center">

Built by **[5Exceptions Software Solutions](https://5exceptions.com)**

</div>
