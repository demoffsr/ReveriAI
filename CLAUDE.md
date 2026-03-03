# ReveriAI

iOS dream journal app — SwiftUI + SwiftData. Record dreams via voice/text, AI interpretation, journal with filters, day/night dynamic theme.

## Language

User communicates in Russian. Spec (`reveri-spec.md`) is in Russian.

## Build

```bash
xcodebuild -scheme ReveriAI -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

Xcode project (not Tuist/SPM). Simulators: iPhone 17 Pro, iPhone 17 Pro Max, iPhone Air (iOS 26.1).

## Secrets Management

**Xcconfig-based configuration** — API keys stored in git-ignored `Secrets.xcconfig`, injected via `Info.plist` at build time, read via `Bundle.main.infoDictionary` at runtime.

**Setup (new environment):**
1. Create `Secrets.xcconfig` in project root with:
   ```
   SLASH = /
   SUPABASE_PROJECT_URL = https:$(SLASH)$(SLASH)bvydopjjndfgbhjczyis.supabase.co
   SUPABASE_ANON_KEY = <your-key-here>
   ```
2. Xcconfig already linked to Debug/Release in `project.pbxproj`
3. Build will fail with clear error if file missing

**Adding new secrets:** Add to `Secrets.xcconfig` → `ReveriAI/Info.plist` → read via `Bundle.main.infoDictionary?["KEY"] as? String`. `SLASH = /` trick because `//` is parsed as comment mid-line.

## Architecture

- **Pure SwiftUI + Observation** — no Combine, no UIKit
- **SwiftData** for persistence (`Dream` model, `DreamEmotion` enum, `DreamFolder` model)
- **Entry:** `ReveriAIApp.swift` → `RootView` → tab-based (`RecordView`, `JournalView`)
- **Theme:** `ThemeManager` (`@Observable`) via `@Environment(\.theme)`, auto day(5–21h)/night(21–5h)
- **ViewModels:** `@State private var viewModel = ...` pattern (Observation, not ObservableObject)

## Project Structure

```
ReveriAI/
├── App/                    # RootView, AppTab
├── Features/
│   ├── Record/             # RecordView, RecordViewModel, TextModeView, HowDidItFeelCard, SaveDreamButton
│   ├── Journal/            # JournalView, JournalViewModel, DreamCard, DreamCardPlayer, DreamDetailView, FolderCard, FolderDetailView, FolderPickerSheet, AddDreamsToFolderSheet, FolderSearchBar, filters, EmptyJournalView
│   └── Profile/            # ProfileView (locale picker, dream reminder settings)
├── Components/
│   ├── Header/             # DreamHeader, CelestialIcon
│   ├── Clouds/             # CloudSeparator, Cloud{Back,Mid,Front}Shape, CloudContentArea
│   ├── TabBar/             # ReveriTabBar, TabBarItem
│   ├── AudioWaveform/      # AudioWaveformView (Canvas + TimelineView), WaveformBuffer, CardWaveformView, DreamCardPlayer
│   ├── Toast/              # ToastView (ToastStyle: success/error), ToastModifier
│   └── EmotionPicker/      # EmotionBadge, EmotionTagBadge, EmotionPickerGrid
├── Services/               # AudioRecorder, SpeechRecognitionService, SupabaseService, DreamAIService, ImageCache, NotificationService, DreamReminderManager
├── Config/                 # SupabaseConfig
├── Theme/                  # ThemeManager, ThemeColors, ThemeEnvironment, GlassButtonStyle, PressableButtonStyle
├── Models/                 # Dream, DreamFolder, DreamEmotion, SpeechLocale, DreamReminderAttributes, MockData, DetailDreamState
└── Extensions/             # Color+Hex, Date+Helpers
RecordingActivityWidget/    # Widget Extension (RecordingActivityWidgetExtension target)
```

## Conventions

- Keep views thin, logic in ViewModels
- Theme colors defined in `ThemeColors.swift` as static Color extensions
- Figma designs may be at ~1.6× scale relative to iPhone @1x (390pt width)
- **Glass effect:** Always use `.reveriGlass(.circle)` or `.reveriGlass(.capsule)` (`ReveriAI/Theme/GlassButtonStyle.swift`). Multiple adjacent elements → `GlassEffectContainer(spacing:)`. Overlapping → independent glass + `zIndex`. Never use raw `.glassEffect()` or custom backgrounds. `GlassEffectContainer` draws glass OVER child overlays — if you need overlays on top, don't use the container.
- **Glass in toolbar bug:** `.reveriGlass(.circle)` inside `ToolbarItem` renders as capsule. Fix: custom nav bar HStack + `.toolbar(.hidden, for: .navigationBar)`, apply glass on `Button` itself.
- **Tab switching:** `RootView` uses `ZStack` with `zIndex` only — NO `.opacity()`, NO `.animation()` on ZStack. Adding either causes ghosting.
- **Text concatenation (iOS 26):** Use `Text("\(Text(...).modifier)\(Text(...).modifier)")` string interpolation, NOT `Text + Text` (deprecated).
- **Swift 6 + `@unchecked Sendable`:** Helper classes with NSLock use `nonisolated(unsafe)` on mutable properties and `nonisolated` on methods to avoid MainActor inference from `@Observable` parent.
- **TimelineView + @State timing:** Never initialize time references to `0` or epoch — TimelineView fires before `onAppear`. Use `TimeInterval?` with nil-coalescing.
- **Observation isolation:** Frequent `@Observable` updates (e.g. audio metering ~43Hz) must be consumed in small wrapper views. Pattern: `LiveWaveformView`.
- **Complex view type-check:** When compiler fails "unable to type-check", extract `body` into computed properties + helper functions, use explicit `{ _, _ in }` onChange closures.
- **SQL functions security:** Все public-schema функции должны иметь REVOKE от anon/authenticated и GRANT только service_role. Прямой клиентский RPC-доступ запрещён. При создании новой функции добавлять REVOKE/GRANT блок (см. миграцию 20260302500000).

## Detailed References

Load these files when working on the relevant area:

- `docs/claude/patterns.md` — UI components, state machines, recording flow, speech recognition, navigation
- `docs/claude/ai-services.md` — AI title/image/interpretation, Supabase edge functions, deploy commands
- `docs/claude/performance.md` — caching strategies, Canvas/waveform optimizations, drawingGroup patterns
