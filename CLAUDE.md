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
│   ├── AudioWaveform/      # AudioWaveformView (Canvas + TimelineView), WaveformBuffer
│   ├── Toast/              # ToastView, ToastModifier
│   └── EmotionPicker/      # EmotionBadge, EmotionGrid
├── Services/               # AudioRecorder, SpeechRecognitionService
├── Theme/                  # ThemeManager, ThemeColors, ThemeEnvironment
├── Models/                 # Dream, DreamEmotion, SpeechLocale, MockData
├── Extensions/             # Color+Hex, Date+Helpers
└── Assets.xcassets/        # AppIcon, SunIcon, BackgroundDaylight, VoiceModeIcon, TextModeIcon, VoiceModeButtonIcon, CheckmarkIconAction, StopIcon, PauseIcon, PlayIcon, DeleteIcon, SkipBack5Icon, SkipForward5Icon, MoonIcon{Active,Inactive}, JournalIcon{Active,Inactive} (SVG), AccentColor
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
- **Recording mode:** Tab bar: Stop icon always left, Pause/Play icon always right. Labels migrate: "Stop" label on left when recording, "Resume" label on right when paused. Transition via `.blurReplace` + `.spring`. 3D flip on Pause/Play icon. Mode pill hidden, timer text at `bottomLeading`. Waveform in content area.
- **Review mode (audio only):** Tab bar has two states: **idle** shows Play button (accent, labeled "Play") + Delete button (red trash icon, triggers confirmation alert "Delete recording?"). **Playback active** (`isPlayingPreview`) shows [SkipBack5Icon] — [Large Pause/Play in 56pt cream circle (`theme.accent.opacity(0.15)`)] — [SkipForward5Icon], with `.blurReplace` transition between states. `AudioRecorder` has `skipForward(seconds:)` / `skipBackward(seconds:)` methods. Cloud layer: review timer at `bottomLeading` (`00:00:00 — 00:05:23`), Save Dream button at `bottomTrailing`. Waveform shows playback animation when Play is pressed — scrolls through recorded bars at 60fps, synced with audio duration. Editable `TextEditor` with transcript from speech recognition (placeholder "Add dream description..." when empty). Saved as audio dream with transcript.
- **Audio recording:** `AudioRecorder` service (`@Observable`, NSObject, AVAudioPlayerDelegate). `AVAudioEngine` with input tap for recording (AAC 44.1kHz, `Documents/recordings/`). AVAudioPlayer for playback preview. Metering via `vDSP_maxmgv` + `vDSP_rmsqv` (Accelerate framework), peak/RMS blend (70/30), `cbrtf` curve. Raw curved level dispatched to MainActor — `WaveformBuffer` handles its own smoothing. `NSMicrophoneUsageDescription` in project build settings.
- **Speech recognition:** `SpeechRecognitionService` (`@Observable`) with 3-tier fallback: **Tier 1** `SpeechAnalyzer`/`SpeechTranscriber` (iOS 26+, on-device, no time limit, 37+ locales incl. ru_RU) → **Tier 2** `SFSpeechRecognizer` (fallback) → **Tier 3** WhisperKit (stub). Auto-selects best engine per locale. Exposes `transcribedText`, `partialText`, `stableText`, `latestText`, `isTranscribing`, `currentEngine` enum. `BufferConverter` handles audio format conversion for SpeechAnalyzer. `startTranscription(locale:audioStream:)` takes explicit `Locale` from user's picker selection. Both engines use `AudioBufferRelay` (NSLock-based pub/sub fan-out) for session restart loops — when a session ends (speech pause or SF 1-min limit), partial text is committed via `pauseTranscription()` and a new session subscribes to the relay. **SF silent reset detection:** SFSpeechRecognizer silently resets `bestTranscription.formattedString` on new utterance without sending `isFinal`. Detected by comparing first characters (case-insensitive) of consecutive results + text shrink heuristic. On detection, previous text is auto-committed. `lowercaseFirst` applied when appending segments — but skipped after sentence-ending punctuation (`.?!`) to preserve capitalization. **Simulator note:** SpeechAnalyzer is unavailable on iOS Simulator — falls back to SFSpeechRecognizer (Tier 2).
- **Punctuation post-processing:** Apple's `addsPunctuation` works for English but NOT for Russian. `punctuateSegment()` adds `.` or `?` at segment commit boundaries (speech pauses, session restarts, isFinal). Question detection: skips Russian filler words at the start (а, ну, и, но, да, так, вот, ведь, же), then checks if the first significant word is a question word (почему, где, кто, что, когда, сколько, etc.) → `?`. Also detects «ли» particle anywhere → `?`. No-op if text already has punctuation (English). Applied in `pauseTranscription()`, SF auto-commit, SF isFinal, and SA isFinal. SF also has `request.addsPunctuation = true` + `requiresOnDeviceRecognition` for English.
- **Locale picker:** `SpeechLocale` enum (13 locales: RU, EN, DE, FR, ES, IT, PT, JA, KO, ZH, AR, TR, HI). Persisted via `@AppStorage("speechRecognitionLocale")`. Picker UI in `JournalHeader` — avatar circle shows 2-letter locale code, tapping opens `Menu` with all locales + checkmark. `RecordView` reads same `@AppStorage` key to pass locale to speech service.
- **Live captions:** SF Pro 15pt, tracking -0.23, lineSpacing 5. Latest in-progress word styled with `LinearGradient` (black → accent). Uses `Text` string interpolation with embedded styled `Text` views (NOT `Text + Text` which is deprecated in iOS 26). Wrapped in `ScrollView`, positioned directly under waveform with 8pt spacing. 100pt bottom padding for tab bar clearance.
- **Audio waveform:** `AudioWaveformView` uses `Canvas` + `TimelineView(.animation)` for 60fps rendering. Three modes: **recording** (bars grow left-to-right from live audio level), **review static** (shows playback position from `playbackProgress`), **playback** (smooth 60fps scroll driven by `TimelineView`, speed = `totalRecordedOffset / playbackDuration`). `WaveformBuffer` (plain class, NOT @Observable) stores bars — mutations don't trigger SwiftUI state diffs, no trim limit (all bars preserved for playback). New bars only generated during recording (`isAnimating`). Bar width 2pt, spacing 3.6pt, height 4–100pt (frame 120pt). Level smoothing: fast attack (0.3/0.7), moderate decay (0.8/0.2). `totalRecordedOffset` captured when recording ends via `onChange(of: isAnimating)`. Playback start/pause managed by `onChange(of: isPlayingBack)` — captures/restores scroll position. **Playback window:** During playback/review, playhead positioned at 20% from left edge (`visibleWidth = size.width * 0.2`) so scrolling is visible from the first second. During recording, full width used. **Skip sync:** `onChange(of: playbackProgress)` detects jumps (delta > 2%) and re-syncs `playbackAnimStartOffset`/`playbackAnimStartTime`. **Critical:** `animationStartTime` must be `TimeInterval?` (not `= 0`) — TimelineView fires before `onAppear`, causing `elapsed` overflow if initialized to epoch. `LiveWaveformView` wrapper in RecordView isolates observation of `audioRecorder.currentLevel` (recording) and `audioRecorder.playbackCurrentTime` (review) so only the small wrapper re-evaluates, not RecordView. **ViewBuilder pitfall:** `if/else` with `let` assignment inside `TimelineView` closure breaks generic inference — extract into a regular `func` instead.
- **Assets:** SVG icons stored with `preserves-vector-representation`. Tab icons use `template-rendering-intent: original` (colors in SVG). Header/mode icons use `template` rendering. `CheckmarkIconAction`, `StopIcon`, `PauseIcon`, `PlayIcon`, `DeleteIcon`, `SkipBack5Icon`, `SkipForward5Icon` use `original` rendering.

## Conventions

- Keep views thin, logic in ViewModels
- Theme colors defined in `ThemeColors.swift` as static Color extensions
- Figma designs may be at ~1.6× scale relative to iPhone @1x (390pt width)
- **SwiftUI struct pitfall:** Never read `let` properties inside long-running `Task` closures — they capture the value at creation time. Use `onChange(of:)` instead for reactive updates.
- **Observation isolation:** When an `@Observable` property updates frequently (e.g. audio metering ~43Hz), wrap consumers in a small private struct to prevent heavy parent views from re-evaluating. Pattern: `LiveWaveformView` wrapper.
- **Text concatenation (iOS 26):** Use `Text("\(Text(...).style)\(Text(...).style)")` string interpolation, NOT `Text + Text` (deprecated).
- **Swift 6 concurrency with `@unchecked Sendable`:** Helper classes with manual synchronization (NSLock) use `nonisolated(unsafe)` on mutable stored properties and `nonisolated` on methods to avoid MainActor isolation inference from `@Observable` parent context.
- **TimelineView + @State timing:** Never initialize `@State` time references to `0` or epoch — `TimelineView` content closure fires before `onAppear`/`onChange`. Use optionals (`TimeInterval?`) with nil-coalescing (`animationStartTime ?? now`) to safely handle the first frame.
- **Canvas performance:** For high-frequency data (waveform bars), use a plain class buffer (`@State private var buffer = MyBuffer()`) instead of `@State` arrays. Class mutations don't trigger SwiftUI diffs. Only `TimelineView` drives redraws.
