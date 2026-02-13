# ReveriAI

iOS dream journal app — SwiftUI + SwiftData. Record dreams via voice/text, AI interpretation, journal with filters, day/night dynamic theme.

## Language

User communicates in Russian. Spec (`reveri-spec.md`) is in Russian.

## Build

```bash
xcodebuild -scheme ReveriAI -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

Xcode project (not Tuist/SPM). Simulators: iPhone 17 Pro, iPhone 17 Pro Max, iPhone Air (iOS 26.1).

## Architecture

- **Pure SwiftUI + Observation** — no Combine, no UIKit
- **SwiftData** for persistence (`Dream` model, `DreamEmotion` enum)
- **Entry:** `ReveriAIApp.swift` → `RootView` → tab-based (`RecordView`, `JournalView`)
- **Theme:** `ThemeManager` (`@Observable`) injected via `@Environment(\.theme)`, auto day(5–21h)/night(21–5h)
- **ViewModels:** `@State private var viewModel = ...` pattern (Observation framework, not ObservableObject)

## Project Structure

```
ReveriAI/
├── App/                    # RootView, AppTab
├── Features/
│   ├── Record/             # RecordView, RecordViewModel, TextModeView, HowDidItFeelCard, SaveDreamButton
│   └── Journal/            # JournalView, JournalViewModel, DreamCard, filters, EmptyJournalView
├── Components/
│   ├── Header/             # DreamHeader, CelestialIcon
│   ├── Clouds/             # CloudSeparator, Cloud{Back,Mid,Front}Shape, CloudContentArea
│   ├── TabBar/             # ReveriTabBar, TabBarItem
│   ├── AudioWaveform/      # AudioWaveformView (Canvas + TimelineView)
│   ├── Toast/              # ToastView, ToastModifier
│   └── EmotionPicker/      # EmotionBadge, EmotionGrid
├── Services/               # AudioRecorder, SpeechRecognitionService
├── Theme/                  # ThemeManager, ThemeColors, ThemeEnvironment
├── Models/                 # Dream, DreamEmotion, SpeechLocale, MockData
├── Extensions/             # Color+Hex, Date+Helpers
└── Assets.xcassets/        # AppIcon, SunIcon, BackgroundDaylight, VoiceModeIcon, TextModeIcon, VoiceModeButtonIcon, CheckmarkIconAction, StopIcon, PauseIcon, PlayIcon, DeleteIcon, MoonIcon{Active,Inactive}, JournalIcon{Active,Inactive} (SVG), AccentColor
```

## Key Patterns

- **Cloud system:** 3 cloud Shape layers (Back/Mid/Front) normalized from SVG viewBox 390×159 using 0..1 coords. `CloudSeparator` composes them. `RecordView` controls sizing: `cloudHeight = 159`, `cloudOverhang = cloudHeight * 0.5`.
- **CelestialIcon:** 2 glow rings (102pt/84pt) + main circle (65pt) with gradient stroke + warm shadow. Day = custom SVG sun (`SunIcon` asset), Night = SF Symbol `moon.fill`.
- **Header background:** `DreamHeader` uses `Image("BackgroundDaylight")` with `.resizable().aspectRatio(contentMode: .fill)`, overlaid by a black-to-transparent `LinearGradient` (Figma devmode values) + `StarsCanvas`. In `RecordView`, the header frame is `headerHeight + cloudOverhang` with `.clipped()` so the photo extends behind clouds but doesn't bleed into the white content area.
- **Header layout:** Layered ZStack in RecordView — background, content, header image, title+icon, clouds+pill. Title shifts up on keyboard focus.
- **Mode switch pill:** `.glassEffect(.clear.interactive(), in: .capsule)` with white stroke overlay. Shows the *opposite* mode (i.e. what you can switch to). Custom SVG icons: `VoiceModeIcon`, `TextModeIcon`. Positioned at `bottomTrailing` of cloud layer with `offset(y: cloudOverhang + 30)`.
- **Save Dream button:** Appears in text mode when `canSave` is true, and in review mode at `bottomTrailing`. Glass effect + white stroke (same style as mode pill). Background: `theme.accent.opacity(0.1)`, text: `theme.accent` (100%). Icon: `CheckmarkIconAction` (original rendering, orange SVG).
- **Text input:** `TextModeView` uses `.tint(theme.accent)` for orange cursor/selection. Top padding `36pt` to clear the pill buttons.
- **Tab bar:** Glass effect (`.glassEffect(.clear, in: .capsule)`) + white stroke overlay. Custom SVG icons with `original` rendering (colors baked in SVG: active = #FFAA00, inactive = black@0.3). `AppTab` has `activeIcon`/`inactiveIcon` properties. Selected tab has `accentColor.opacity(0.15)` capsule background. Label: SF Pro 15 medium, accentColor. Animation: expand on tap → collapse after 1.5s via cancellable `Task`. No `.interactive()` on glass (causes yellow flash). Three-state body: normal tabs / recording controls / review controls.
- **Recording state machine:** `idle → recording → (transcript? text mode : reviewing) → idle`. States `isRecording`/`isPaused`/`isReviewing` live in `RootView`, flow via `@Binding` to `RecordView` and as values + closures to `ReveriTabBar`. `AudioRecorder` and `SpeechRecognitionService` also live in `RootView` (shared between RecordView and tab bar). Recording < 1s auto-discards.
- **Voice → text flow:** After recording stops, if transcript exists → copy to `viewModel.dreamText`, switch to text mode, delete audio file. User edits and saves as text dream. If no transcript → fall back to audio review mode.
- **Recording mode:** Tab bar shows Stop (red) + Pause/Resume (3D flip). Mode pill hidden, timer text at `bottomLeading`. Waveform in content area.
- **Review mode (audio only):** Tab bar shows Preview (accent, Play/Pause with 3D flip) + Delete (red trash icon). Cloud layer: review timer at `bottomLeading` (`00:00:00 — 00:05:23`), Save Dream button at `bottomTrailing`. Waveform frozen (`isAnimating: false, level: 0`).
- **Audio recording:** `AudioRecorder` service (`@Observable`, NSObject, AVAudioPlayerDelegate). AVAudioRecorder for recording (AAC 44.1kHz, `Documents/recordings/`). AVAudioPlayer for playback preview. Metering every 50ms: peak/avg blend (70/30), `pow(10, dB/20)` amplitude conversion, `cbrtf` curve, asymmetric smoothing (fast attack 0.3/0.7, slow decay 0.6/0.4). `NSMicrophoneUsageDescription` in project build settings.
- **Speech recognition:** `SpeechRecognitionService` (`@Observable`) with 3-tier fallback: **Tier 1** `SpeechAnalyzer`/`SpeechTranscriber` (iOS 26+, on-device, no time limit, 37+ locales incl. ru_RU) → **Tier 2** `SFSpeechRecognizer` (fallback, auto-restarts on 1-min limit with text stitching via `AudioBufferRelay`) → **Tier 3** WhisperKit (stub). Auto-selects best engine per locale. Exposes `transcribedText`, `partialText`, `stableText`, `latestText`, `isTranscribing`, `currentEngine` enum. `BufferConverter` handles audio format conversion for SpeechAnalyzer. `startTranscription(locale:audioStream:)` takes explicit `Locale` from user's picker selection.
- **Locale picker:** `SpeechLocale` enum (13 locales: RU, EN, DE, FR, ES, IT, PT, JA, KO, ZH, AR, TR, HI). Persisted via `@AppStorage("speechRecognitionLocale")`. Picker UI in `JournalHeader` — avatar circle shows 2-letter locale code, tapping opens `Menu` with all locales + checkmark. `RecordView` reads same `@AppStorage` key to pass locale to speech service.
- **Live captions:** SF Pro 15pt, tracking -0.23, lineSpacing 5. Latest in-progress word styled with `LinearGradient` (black → accent). Uses `Text` string interpolation with embedded styled `Text` views (NOT `Text + Text` which is deprecated in iOS 26). Wrapped in `ScrollView` with `.defaultScrollAnchor(.bottom)` for auto-scroll. Positioned directly under waveform, 100pt bottom padding for tab bar clearance.
- **Audio waveform:** `AudioWaveformView` uses `Canvas` + `TimelineView(.animation)` for 60fps rendering. Scroll offset computed from `timeline.date` (no separate Task). Bars fed via `onChange(of: level)`. Bar width 2pt, spacing 3.6pt, height 4–100pt (frame 120pt). **Observation isolation:** `LiveWaveformView` wrapper in RecordView isolates `audioRecorder.currentLevel` subscription so only the small wrapper re-evaluates ~43 times/sec, not the entire RecordView.
- **Assets:** SVG icons stored with `preserves-vector-representation`. Tab icons use `template-rendering-intent: original` (colors in SVG). Header/mode icons use `template` rendering. `CheckmarkIconAction`, `StopIcon`, `PauseIcon`, `PlayIcon`, `DeleteIcon` use `original` rendering.

## Conventions

- Keep views thin, logic in ViewModels
- Theme colors defined in `ThemeColors.swift` as static Color extensions
- Figma designs may be at ~1.6× scale relative to iPhone @1x (390pt width)
- **SwiftUI struct pitfall:** Never read `let` properties inside long-running `Task` closures — they capture the value at creation time. Use `onChange(of:)` instead for reactive updates.
- **Observation isolation:** When an `@Observable` property updates frequently (e.g. audio metering ~43Hz), wrap consumers in a small private struct to prevent heavy parent views from re-evaluating. Pattern: `LiveWaveformView` wrapper.
- **Text concatenation (iOS 26):** Use `Text("\(Text(...).style)\(Text(...).style)")` string interpolation, NOT `Text + Text` (deprecated).
- **Swift 6 concurrency with `@unchecked Sendable`:** Helper classes with manual synchronization (NSLock) use `nonisolated(unsafe)` on mutable stored properties and `nonisolated` on methods to avoid MainActor isolation inference from `@Observable` parent context.
