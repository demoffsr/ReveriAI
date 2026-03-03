# Reveri — Dream Journal for iOS

Reveri is an iOS app for capturing dreams the moment you wake up — via voice or text — with real-time transcription, a dynamic day/night theme, and a dream journal.

Built with **SwiftUI**, **SwiftData**, and the **Observation** framework. Targets **iOS 26+**.

---

## Features

### Voice Recording with Live Transcription
Record your dream by speaking. The app captures audio and transcribes speech in real-time using a 3-tier recognition engine:
- **Tier 1:** `SpeechAnalyzer` / `SpeechTranscriber` (iOS 26+) — on-device, no time limit, 37+ locales
- **Tier 2:** `SFSpeechRecognizer` — fallback with auto-restart on the 1-minute limit
- **Tier 3:** WhisperKit — planned

Supports 13 languages: Russian, English, German, French, Spanish, Italian, Portuguese, Japanese, Korean, Chinese, Arabic, Turkish, Hindi.

### Live Audio Waveform
A real-time animated waveform visualizes your voice as you speak. Bars grow left-to-right, respond to volume, and scroll once they fill the screen. Rendered at 60fps via `Canvas` + `TimelineView` with zero SwiftUI state overhead.

### Text Mode
Switch to text input at any time. After voice recording, the transcript is automatically transferred to the text editor for review and editing before saving.

### Dream Journal
Browse all recorded dreams in a chronological journal with emotion tags. Filter and search through your dream history.

### Dynamic Day/Night Theme
The entire UI adapts to time of day:
- **Day (5:00–21:00):** dark starry header, golden sun icon with glow rings, warm sand-colored clouds, orange accents
- **Night (21:00–5:00):** deep night sky header, silver moon, cool blue clouds, blue accents

### Glass Effect Tab Bar
A custom floating tab bar with `glassEffect` and animated transitions:
- **Normal mode:** two tabs (Record, Journal) with expand-on-tap animation
- **Recording mode:** Stop + Pause controls with 3D flip animation; labels smoothly migrate between buttons on pause
- **Review mode:** Preview playback + Delete with the same glass styling

---

## Architecture

```
ReveriAI/
├── App/                    # RootView, AppTab
├── Features/
│   ├── Record/             # RecordView, RecordViewModel, TextModeView
│   └── Journal/            # JournalView, JournalViewModel, DreamCard
├── Components/
│   ├── Header/             # DreamHeader, CelestialIcon
│   ├── Clouds/             # CloudSeparator, 3-layer SVG cloud shapes
│   ├── TabBar/             # ReveriTabBar with glass effect
│   ├── AudioWaveform/      # Canvas + TimelineView waveform
│   ├── Toast/              # ToastView
│   └── EmotionPicker/      # EmotionBadge, EmotionGrid
├── Services/               # AudioRecorder, SpeechRecognitionService
├── Theme/                  # ThemeManager, ThemeColors, ThemeEnvironment
├── Models/                 # Dream (SwiftData), DreamEmotion, SpeechLocale
└── Extensions/             # Color+Hex, Date+Helpers
```

**Key principles:**
- Pure SwiftUI + Observation framework — no Combine, no UIKit
- SwiftData for persistence
- `@Observable` ViewModels with `@State private var viewModel` pattern
- Theme injected via `@Environment(\.theme)` with automatic day/night switching
- Frequent observation updates (audio metering ~43Hz) isolated in small wrapper views

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| UI | SwiftUI, Canvas, TimelineView, GlassEffect |
| Data | SwiftData |
| State | Observation framework (`@Observable`) |
| Audio | AVAudioEngine, AVAudioPlayer |
| Speech | SpeechAnalyzer (iOS 26), SFSpeechRecognizer |
| DSP | Accelerate (vDSP) |
| Target | iOS 26.1+, iPhone |

---

## Build

```bash
xcodebuild -scheme ReveriAI \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build
```

Requires Xcode with iOS 26 SDK.

---

## Roadmap

- [ ] AI dream interpretation (multiple psychological lenses)
- [ ] Dream analytics and statistics
- [ ] HealthKit integration (sleep phases, heart rate correlation)
- [ ] Sleep mode with Live Activity on Lock Screen
- [ ] Siri Shortcuts ("Record a dream")
- [ ] WhisperKit fallback for offline transcription
- [ ] Night theme refinement

---

## License

Private project. All rights reserved.
