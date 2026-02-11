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
│   ├── Toast/              # ToastView, ToastModifier
│   └── EmotionPicker/      # EmotionBadge, EmotionGrid
├── Theme/                  # ThemeManager, ThemeColors, ThemeEnvironment
├── Models/                 # Dream, DreamEmotion, MockData
├── Extensions/             # Color+Hex, Date+Helpers
└── Assets.xcassets/        # AppIcon, SunIcon, VoiceModeIcon, TextModeIcon, MoonIcon{Active,Inactive}, JournalIcon{Active,Inactive} (SVG), AccentColor
```

## Key Patterns

- **Cloud system:** 3 cloud Shape layers (Back/Mid/Front) normalized from SVG viewBox 390×159 using 0..1 coords. `CloudSeparator` composes them. `RecordView` controls sizing: `cloudHeight = 159`, `cloudOverhang = cloudHeight * 0.5`.
- **CelestialIcon:** 2 glow rings (102pt/84pt) + main circle (65pt) with gradient stroke + warm shadow. Day = custom SVG sun (`SunIcon` asset), Night = SF Symbol `moon.fill`.
- **Header layout:** Layered ZStack in RecordView — background, content, gradient header, title+icon, clouds+pill. Title shifts up on keyboard focus.
- **Mode switch pill:** `.glassEffect(.clear.interactive(), in: .capsule)` with white stroke overlay. Shows the *opposite* mode (i.e. what you can switch to). Custom SVG icons: `VoiceModeIcon`, `TextModeIcon`.
- **Tab bar:** Glass effect (`.glassEffect(.clear, in: .capsule)`) + white stroke overlay. Custom SVG icons with `original` rendering (colors baked in SVG: active = #FFAA00, inactive = black@0.3). `AppTab` has `activeIcon`/`inactiveIcon` properties. Selected tab has `accentColor.opacity(0.15)` capsule background. Label: SF Pro 15 medium, accentColor. Animation: expand on tap → collapse after 1.5s via cancellable `Task`. No `.interactive()` on glass (causes yellow flash).
- **Assets:** SVG icons stored with `preserves-vector-representation`. Tab icons use `template-rendering-intent: original` (colors in SVG). Header/mode icons use `template` rendering.

## Conventions

- Keep views thin, logic in ViewModels
- Theme colors defined in `ThemeColors.swift` as static Color extensions
- Figma designs may be at ~1.6× scale relative to iPhone @1x (390pt width)
