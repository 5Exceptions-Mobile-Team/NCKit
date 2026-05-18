# NCKit — On-device Noise Cancellation for iOS

Drop-in NCKit noise cancellation for iOS apps. 100% on-device — no network, no API keys, no server. Ships as a single closed-source XCFramework: you drag it in, `import NCKit`, and call the API.

Under the hood this wraps the official [DeepFilterNet](https://github.com/Rikorose/DeepFilterNet) `libdf` Rust runtime. You do not need Rust, ONNX Runtime, a bridging header, or any pod to integrate. The model file is already embedded in the framework.

---

## What's in the box

```
NCKit/
└── NCKit.xcframework/        # everything you need. One artifact. Drag in, done.
```

That's it. No source files, no bridging header, no separate model file to remember. The `.xcframework` contains:

- Compiled Swift wrapper (public API: `NCKitProcessor`, `NCKitFileProcessor`, `NCKitModelLocator`, `NCKitAudioNormalizer`, `NCKitError`)
- The libdf Rust runtime (statically linked into the framework binary)
- `NCKit_model.tar.gz` (~7.6 MB model, embedded as a framework resource)
- Two slices: `ios-arm64` (device) and `ios-arm64-simulator` (Apple Silicon Mac)

Internal implementation details — Rust sources, the libdf C API, the Swift wrapper bodies — are **not** in the distribution. Consumers see only public Swift method signatures via the `.swiftinterface` file.

---

## Requirements

- iOS 16.0+
- Xcode 15+
- Apple Silicon Mac (the simulator slice is arm64-only; device builds work from any Mac)

---

## Sample app

A complete, commented reference integration is included in the repo at `KrispyiOS/`. It shows every integration pattern end-to-end:

| File | What it demonstrates |
|---|---|
| `NCKitSample/Audio/AudioEngine.swift` | Real-time mic: `NCKitModelLocator`, `NCKitProcessor`, AVAudioEngine |
| `NCKitSample/Audio/VideoProcessor.swift` | File/video: `NCKitFileProcessor` + `NCKitAudioNormalizer` |
| `NCKitSample/UI/HowToUseView.swift` | In-app API usage snippets |

---

## Integration (3 steps, ~2 minutes)

### 1. Drag in the XCFramework

Drag `NCKit.xcframework` into your Xcode project navigator. When prompted:
- **Copy items if needed:** on
- **Add to targets:** your app target

### 2. Embed & Sign

Target → **General** → **Frameworks, Libraries, and Embedded Content** →
find `NCKit.xcframework` and set its embed option to **Embed & Sign**.

### 3. Build

There's no bridging header to configure, no model file to bundle separately, no Rust toolchain or `pod install`. Import and go:

```swift
import NCKit
```

---

## Usage

### One-shot: denoise a file (audio or video → WAV)

The simplest path. Works for `.m4a`, `.wav`, `.mp3`, `.mp4`, `.mov` — anything `AVFoundation` can read.

```swift
import NCKit
import Foundation

let modelURL = try NCKitModelLocator.modelTarGzURL()
let processor = try NCKitProcessor(modelURL: modelURL)

let inputURL  = Bundle.main.url(forResource: "noisy", withExtension: "m4a")!
let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("clean.wav")

try NCKitFileProcessor.processFile(
    inputURL: inputURL,
    outputURL: outputURL,
    processor: processor
)

// Optional: match levels across recordings before delivery
var samples = try loadFloatSamples(from: outputURL)         // your helper
NCKitAudioNormalizer.applySpeechGatedMakeupGain(&samples, sampleRate: 48_000)
try writeWav(samples, sampleRate: 48_000, to: outputURL)    // your helper
```

Output is 48 kHz mono 16-bit PCM WAV. Mux it back into a video container with `AVAssetExportSession` or `AVAssetWriter` if you started from video.

`NCKitModelLocator.modelTarGzURL()` auto-resolves the embedded model from inside the framework bundle — you don't have to ship the `.tar.gz` with your app.

### Streaming: denoise frame-by-frame

For live capture, microphone streams, or custom pipelines. `NCKitProcessor` is frame-synchronous; feed it exactly `processor.frameLength` samples at a time (it's 480 for NCKit — 10 ms at 48 kHz).

```swift
import NCKit

let processor = try NCKitProcessor(modelURL: NCKitModelLocator.modelTarGzURL())
let hop = processor.frameLength   // 480 samples

var input  = [Float](repeating: 0, count: hop)
var output = [Float](repeating: 0, count: hop)

// From your audio source (AVAudioEngine tap, AudioUnit render callback, etc.):
func onHop(_ hopSamples: [Float]) {
    input.withUnsafeMutableBufferPointer { ib in
        output.withUnsafeMutableBufferPointer { ob in
            processor.processFrame(input: ib.baseAddress!, output: ob.baseAddress!)
        }
    }
    // `output` now holds the denoised hop.
}
```

> **Latency.** libdf introduces a 2-frame look-ahead for deep filtering (~20 ms). The first 2 output hops after init are silence. For offline files `NCKitFileProcessor` already compensates for this; for live streams you'll want to skip or delay equivalently on the UI side.

---

## Tuning knobs

```swift
let processor = try NCKitProcessor(
    modelURL: modelURL,
    attenLimDb: 100,        // noise attenuation ceiling. 100 = unlimited (recommended).
    postFilterBeta: 0       // post-filter strength. 0 = off (matches CLI default).
)
```

Why these defaults?

- **`attenLimDb: 100`** — matches the `deep-filter` CLI. Capping this (say, to 24 dB) causes the model to leave residual noise in very loud environments (engines, pneumatic tools) because it can't attenuate hard enough to catch the peak. Leave it unlimited unless you're deliberately keeping background ambience.
- **`postFilterBeta: 0`** — the reference CLI only enables the post-filter when the user passes `--pf`. Enabling it (e.g. 0.02) adds a slight additional smoothing at the cost of some vocal naturalness. Start with 0 and only enable if your test audio has musical-noise artifacts.

Change either at runtime:

```swift
processor.setAttenLim(50)          // cap attenuation, e.g. to preserve some ambience
processor.setPostFilterBeta(0.02)  // enable CLI-equivalent post-filter
```

### When to use `NCKitAudioNormalizer`

Use it when recordings across sessions come out at wildly different vocal levels — e.g. different users, different phone-to-mouth distances, mixed indoor/outdoor. It measures only the speech portion of the clip (robust against silence and noise), computes one scalar gain targeting −18 dBFS, and soft-limits to −1 dBTP.

**Do not add additional dynamic range compression, limiters, or per-frame gain after the denoiser.** The floor is already near silence; any time-varying gain will re-introduce pumping. This was a deliberate design choice.

---

## Public API (what `.swiftinterface` exposes)

```swift
public final class NCKitProcessor {
    public init(modelURL: URL, attenLimDb: Float = 100, postFilterBeta: Float = 0) throws
    public let frameLength: Int
    @discardableResult
    public func processFrame(input: UnsafeMutablePointer<Float>,
                             output: UnsafeMutablePointer<Float>) -> Float
    public func setAttenLim(_ db: Float)
    public func setPostFilterBeta(_ b: Float)
}

public enum NCKitModelLocator {
    public static var defaultBundle: Bundle { get }
    public static func modelTarGzURL(bundle: Bundle = defaultBundle) throws -> URL
}

public enum NCKitFileProcessor {
    public static let targetSampleRate: Double
    public static func processFile(inputURL: URL, outputURL: URL, processor: NCKitProcessor) throws
}

public enum NCKitAudioNormalizer {
    public static func applySpeechGatedMakeupGain(
        _ samples: inout [Float], sampleRate: Int,
        targetRmsDbfs: Float = -18, maxGainDb: Float = 15, peakCeilingDbfs: Float = -1)
    public static func softLimitInPlace(_ samples: inout [Float], peakCeilingDbfs: Float = -1)
}

public enum NCKitError: Error, Sendable {
    case missingModel(String), libraryInit, badFrameLength(Int),
         cannotOpenInput, cannotCreateOutput, unsupportedFormat, resampleFailed
}
```

---

## Troubleshooting

**Build error: `No such module 'NCKit'`**
The xcframework isn't linked. Target → General → Frameworks, Libraries, and Embedded Content → confirm `NCKit.xcframework` is listed with **Embed & Sign**.

**Launch crash: `dyld: Library not loaded: @rpath/NCKit.framework/NCKit`**
The framework was linked but not embedded. Change its setting from *Do Not Embed* to **Embed & Sign**.

**Runtime error: `NCKitError.missingModel`**
The embedded model couldn't be found. This usually means the xcframework got corrupted during copy — re-extract it fresh from the distribution archive and re-drag it in.

**Runtime error: `NCKitError.libraryInit`**
`df_create` returned null. Most common cause: the embedded model is corrupted. Re-extract the xcframework.

**Simulator link error about `arm64`**
You're on Intel Mac — the simulator slice is `arm64-simulator` only. Build on Apple Silicon, or run on device.

**App Store upload rejected with ITMS-90171 / ITMS-90432**
You have `Embed Without Signing` or a static archive configured. XCFrameworks containing dynamic frameworks must be **Embed & Sign**; never drag the raw `.framework` folder into Copy Bundle Resources.

**Output sounds worse than the DeepFilterNet CLI on the same file**
The pipeline is numerically aligned with the CLI when using default settings (`attenLimDb: 100`, `postFilterBeta: 0`). If output drifts, check:
1. No post-processing (compression, limiting, EQ) is running after `processFrame`.
2. The sample rate going in is actually 48 kHz (NCKitFileProcessor resamples automatically; streaming pipelines don't).
3. You're not reusing a `NCKitProcessor` across unrelated sessions — GRU state accumulates. Create a fresh instance per recording.

---

## How it works (so you can debug)

```
 audio in ─► AVAudioConverter ─► 48 kHz mono Float ─► NCKitProcessor ─► WAV out
                                      (480-sample hops)       │
                                                              └─► libdf (Rust, embedded)
                                                                   ├─ STFT
                                                                   ├─ ERB encoder (ONNX/tract)
                                                                   ├─ GRU (state held in Rust)
                                                                   ├─ Deep filter decoder
                                                                   ├─ Post-filter (optional)
                                                                   └─ iSTFT
```

- **Model format.** `NCKit_model.tar.gz` (inside the framework) contains `enc.onnx`, `erb_dec.onnx`, `df_dec.onnx`, and `config.ini`. libdf extracts it at runtime to a temp directory and runs the three ONNX models via `tract` (a pure-Rust inference runtime — no ONNX Runtime dependency).
- **GRU state.** Fully managed inside Rust. You do not pass hidden-state tensors. Destroy the `NCKitProcessor` and create a new one to reset.
- **Thread safety.** `NCKitProcessor` is not `Sendable`. Use one instance per processing queue, or guard with a lock.

---

## License

- **libdf (the Rust runtime) and the NCKit model weights**: Apache 2.0 / MIT dual-licensed per upstream [DeepFilterNet](https://github.com/Rikorose/DeepFilterNet).
- **The Swift wrapper and packaging** in this framework is yours to use within the context of the project it's distributed with.

Attribution for the DeepFilterNet paper is appreciated:

> Schröter, H., Escalante-B., A. N., Rosenkranz, T., & Maier, A. (2022).
> DeepFilterNet: Perceptually Motivated Real-Time Speech Enhancement.
> *Interspeech 2022.*
