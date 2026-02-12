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
├── Services/               # AudioRecorder (AVAudioRecorder + AVAudioPlayer wrapper)
├── Theme/                  # ThemeManager, ThemeColors, ThemeEnvironment
├── Models/                 # Dream, DreamEmotion, MockData
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
- **Recording state machine:** `idle → recording → reviewing → idle`. States `isRecording`/`isPaused`/`isReviewing` live in `RootView`, flow via `@Binding` to `RecordView` and as values + closures to `ReveriTabBar`. `AudioRecorder` also lives in `RootView` (shared between RecordView and tab bar). Recording < 1s auto-discards (no review).
- **Recording mode:** Tab bar shows Stop (red) + Pause/Resume (3D flip). Mode pill hidden, timer text at `bottomLeading`. Waveform in content area.
- **Review mode:** Tab bar shows Preview (accent, Play/Pause with 3D flip) + Delete (red trash icon). Cloud layer: review timer at `bottomLeading` (`00:00:00 — 00:05:23`), Save Dream button at `bottomTrailing`. Waveform frozen (`isAnimating: false, level: 0`).
- **Audio recording:** `AudioRecorder` service (`@Observable`, NSObject, AVAudioPlayerDelegate). AVAudioRecorder for recording (AAC 44.1kHz, `Documents/recordings/`). AVAudioPlayer for playback preview. Metering every 50ms: peak/avg blend (70/30), `pow(10, dB/20)` amplitude conversion, `cbrtf` curve, asymmetric smoothing (fast attack 0.3/0.7, slow decay 0.6/0.4). `NSMicrophoneUsageDescription` in project build settings.
- **Audio waveform:** `AudioWaveformView` uses `Canvas` + `TimelineView(.animation)` for 60fps rendering. Bars fed via `onChange(of: level)` (NOT via Task — struct `let` properties get captured by value in closures). Scroll right-to-left via `CACurrentMediaTime()` delta. Bar width 2pt, spacing 3.6pt, height 4–100pt (frame 120pt). No SwiftUI view per bar — pure imperative draw for performance.
- **Assets:** SVG icons stored with `preserves-vector-representation`. Tab icons use `template-rendering-intent: original` (colors in SVG). Header/mode icons use `template` rendering. `CheckmarkIconAction`, `StopIcon`, `PauseIcon`, `PlayIcon`, `DeleteIcon` use `original` rendering.

## Conventions

- Keep views thin, logic in ViewModels
- Theme colors defined in `ThemeColors.swift` as static Color extensions
- Figma designs may be at ~1.6× scale relative to iPhone @1x (390pt width)
- **SwiftUI struct pitfall:** Never read `let` properties inside long-running `Task` closures — they capture the value at creation time. Use `onChange(of:)` instead for reactive updates.
