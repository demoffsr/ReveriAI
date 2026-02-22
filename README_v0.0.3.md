# Reveri v0.0.3 — Dream Journal for iOS

> Capture dreams the moment you wake up. Voice or text, AI-powered, with a live Lock Screen presence.

Built with **SwiftUI**, **SwiftData**, and the **Observation** framework. Targets **iOS 26+**.

---

## What's New in v0.0.3

### Recording Live Activity
The app now lives on your Lock Screen while you record. A real-time waveform, a running timer, and a stop button — all without unlocking your phone.

- **LiveWaveformWidget**: 27 animated bars fill left-to-right as you speak. Each bar transitions smoothly from placeholder height to its real amplitude on every update.
- **Dynamic Island**: compact waveform icon + timer; expanded mode with stop button
- **Pause → freeze**: waveform dims to 40% opacity when recording is paused
- Deep link `reveri://stop-recording` from the stop button closes the session instantly

### Dream Reminder Live Activity
Set a bedtime in Profile. The app sends a notification at that time and starts a persistent Lock Screen activity — Record and Write buttons stay there overnight so you can capture dreams the moment you wake up.

### Folders
Organize dreams into named collections.

- **FolderCard**: top 3 most frequent emotions shown as overlapping circles; name + dream count
- **FolderDetailView**: custom nav bar, full-text search, dream list
- **AddDreamsToFolderSheet**: toggle any dream in/out of the folder
- **FolderPickerSheet**: accessible from the DreamCard options menu
- `DreamFolder` SwiftData model with `@Relationship(inverse:)` to `Dream`

### Profile Screen
Push-accessible from the Journal header avatar button.

- Speech recognition language picker (same 13 locales, persisted via `@AppStorage`)
- Dream Reminder toggle + time picker + weekday selector (Mon–Sun circles)
- "Send test notification" button

### App Intents
`StartDreamRecordingIntent` and `StopDreamRecordingIntent` registered with the system — groundwork for Siri Shortcuts and Action Button support.

### Closing Clouds Animation
When the text editor gains focus, cloud shapes slide down from above to cover the header — smooth spring animation (0.45s), asymmetric opacity timing to prevent color bleed through cloud valleys.

### Haptic Feedback
`UIImpactFeedbackGenerator` and `UINotificationFeedbackGenerator` across all key interactions: recording start/stop, save, emotion selection, tab bar buttons.

### Polish
- **Loader screen**: amber background (`#FFAA00` base, `#FF5900` radial glow) with the app logo — seamless handoff from the system launch screen
- **New app icon**: Light and Dark variants
- **Press states**: `PressableButtonStyle` — scale 0.9 + opacity 0.7 on press, 0.15s easeOut
- **Keyboard Done button**: toolbar Done button dismisses text editor from keyboard
- **Toast notifications**: success (green) / error (red) inline toasts for AI feedback
- **Xcconfig secrets**: API keys fully migrated out of source — `Secrets.xcconfig` (git-ignored), injected via `Info.plist`

### Performance
- `.drawingGroup()` on `DreamHeader` (1.3 MB background + gradient + 50-star Canvas) and `CelestialIcon` (blur rings) — renders to Metal texture once, not per-frame
- `LiveWaveformView` and `DetailDreamControlsView` wrapper views isolate high-frequency `@Observable` updates from parent view bodies
- Task lifecycle: fire-and-forget Tasks stored in `@State`, cancelled on tab switch and dismiss
- SwiftData `#Index<Dream>([\.createdAt])` for sort performance with large datasets

---

## Full Feature Set

### Voice Recording
- 3-tier speech recognition engine with automatic fallback:
  - **Tier 1**: `SpeechAnalyzer` / `SpeechTranscriber` (iOS 26+) — on-device, no time limit, 37+ locales
  - **Tier 2**: `SFSpeechRecognizer` — auto-restart on 1-minute limit, silent reset detection
  - **Tier 3**: WhisperKit — planned
- 13 languages: Russian, English, German, French, Spanish, Italian, Portuguese, Japanese, Korean, Chinese, Arabic, Turkish, Hindi
- Russian punctuation post-processing (`.`, `?`) at segment boundaries — Apple's `addsPunctuation` doesn't work for Russian
- Live captions with gradient-styled latest word, `ScrollView` anchored to bottom
- Voice → text flow: after stop, transcript auto-transfers to text editor; audio deleted

### Waveform
- `AudioWaveformView`: `Canvas` + `TimelineView(.animation)` at 60fps, zero SwiftUI state overhead
- Three modes: live recording (bars grow L→R), review static (progress position), playback (scroll synced to audio)
- Playhead at 20% from left edge during playback so scrolling is visible from the first second
- Skip ±5s with jump detection and animation re-sync

### AI Features
- **Title generation**: GPT-4o-mini, 3–5 word concrete titles ("Чай с говорящей кошкой"), locale-aware
- **Image generation**: 2-stage pipeline — GPT-4o-mini generates 3 visual questions → user answers → art prompt → `gpt-image-1` (1024×1024, quality: high) → uploaded to Supabase Storage
- **Dream interpretation**: Jungian analysis — archetypes, shadow, anima/animus, symbolic breakdown, 5 structured sections; GPT-4o-mini, 1500 tokens, locale-aware

### Journal
- Chronological list with search, emotion filter (7 emotions, MRU ordering), time range filter
- `DreamCard`: title, emotion badges, mini waveform player or text preview, date
- `DreamDetailView`: custom nav bar, dream image thumbnail, Dream / Meaning tab segmented picker
- Folders: create, rename, delete, assign dreams

### Emotion System
- 7 emotions: Joyful, In Love, Calm, Confused, Anxious, Scared, Angry
- Post-save flow: `HowDidItFeelCard` slides up above tab bar → `EmotionPickerGrid` (staggered drop animation) → "Dream saved" confirmation → auto-dismiss after 30s
- Filter bar: animated expand/collapse, dimming overlay for unselected emotions, MRU order persists across tab switches

### Theme
- Automatic day/night switch at 5:00 and 21:00
- **Day**: dark starry header, golden sun icon, warm sand clouds, orange accents
- **Night**: deep night sky, silver moon, cool blue clouds, blue accents
- `ThemeManager` (`@Observable`) injected via `@Environment(\.theme)`

### Design System
- `.reveriGlass(.circle)` / `.reveriGlass(.capsule)` — iOS 26 native `glassEffect` with white tint
- `GlassEffectContainer(spacing:)` for adjacent glass elements
- 3-layer SVG cloud shapes (Back/Mid/Front) composited in `CloudSeparator`
- All emotion icons: optimized SVG (4.1 MB → 680 KB via SVGO)

---

## Architecture

```
ReveriAI/
├── App/                    # RootView, AppTab
├── Features/
│   ├── Record/             # RecordView, RecordViewModel, TextModeView, HowDidItFeelCard
│   ├── Journal/            # JournalView, DreamCard, DreamDetailView, FolderCard, FolderDetailView
│   ├── Profile/            # ProfileView
│   └── Loader/             # LoaderView
├── Components/
│   ├── Header/             # DreamHeader, CelestialIcon
│   ├── Clouds/             # CloudSeparator, Cloud{Back,Mid,Front}Shape, CloudClosedShape
│   ├── TabBar/             # ReveriTabBar, TabBarItem
│   ├── AudioWaveform/      # AudioWaveformView (Canvas + TimelineView), WaveformBuffer
│   ├── Toast/              # ToastView (success / error)
│   └── EmotionPicker/      # EmotionBadge, EmotionTagBadge, EmotionPickerGrid
├── Services/               # AudioRecorder, SpeechRecognitionService, SupabaseService,
│                           # DreamAIService, ImageCache, NotificationService,
│                           # DreamReminderManager, LiveActivityManager
├── Theme/                  # ThemeManager, ThemeColors, GlassButtonStyle, PressableButtonStyle
├── Models/                 # Dream, DreamFolder, DreamEmotion, SpeechLocale,
│                           # RecordingActivityAttributes, DreamReminderAttributes
└── Extensions/             # Color+Hex, Date+Helpers
RecordingActivityWidget/    # Widget extension — recording LA + dream reminder LA
```

**Key principles:**
- Pure SwiftUI + Observation — no Combine, no UIKit
- `@Observable` ViewModels with `@State private var viewModel` pattern
- High-frequency observation (audio metering ~43Hz) isolated in small wrapper views
- Theme injected via `@Environment(\.theme)`

---

## Tech Stack

| Layer | Technology |
|-------|------------|
| UI | SwiftUI, Canvas, TimelineView, Liquid Glass |
| Data | SwiftData |
| State | Observation framework (`@Observable`) |
| Audio | AVAudioEngine, AVAudioPlayer |
| Speech | SpeechAnalyzer (iOS 26), SFSpeechRecognizer |
| DSP | Accelerate (vDSP) — peak/RMS metering, audio analysis |
| AI | OpenAI GPT-4o-mini, gpt-image-1 |
| Backend | Supabase Edge Functions (Deno), Supabase Storage |
| Live Activities | ActivityKit, WidgetKit |
| Notifications | UNUserNotificationCenter |
| Target | iOS 26.1+, iPhone |

---

## Build

```bash
xcodebuild -scheme ReveriAI \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build
```

Requires Xcode with iOS 26 SDK.

**Secrets setup** (new environment):
```
# Create Secrets.xcconfig in project root:
SLASH = /
SUPABASE_PROJECT_URL = https:$(SLASH)$(SLASH)<project-id>.supabase.co
SUPABASE_ANON_KEY = <your-key>
```

---

## Edge Functions

```bash
# Title generation
~/bin/supabase functions deploy generate-dream-title --project-ref bvydopjjndfgbhjczyis

# Image generation
~/bin/supabase functions deploy generate-dream-image --project-ref bvydopjjndfgbhjczyis

# Dream interpretation
~/bin/supabase functions deploy generate-dream-interpretation --project-ref bvydopjjndfgbhjczyis
```

---

## Known Issues

- `SpeechAnalyzer` unavailable on Simulator — falls back to `SFSpeechRecognizer`
- Russian punctuation heuristics may fail on complex sentence structures
- Live Activity waveform updates at 1/sec (OS budget) — not real-time

---

## Roadmap

- [ ] WhisperKit fallback (offline transcription)
- [ ] Dream analytics and statistics
- [ ] HealthKit integration (sleep phases, heart rate correlation)
- [ ] Siri Shortcuts ("Record a dream")
- [ ] "Interpret Again" for updated interpretations
- [ ] Export / sharing

---

## Project Stats (v0.0.3)

- **4 Edge Functions**: `generate-dream-title`, `generate-dream-questions`, `generate-dream-image`, `generate-dream-interpretation`
- **2 Live Activity types**: Recording (waveform) + Dream Reminder (overnight lock screen)
- **13 speech recognition languages**
- **7 dream emotions**

---

Built with SwiftUI + SwiftData + Supabase + OpenAI
