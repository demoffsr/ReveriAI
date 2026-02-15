# ReveriAI v0.0.2

iOS dream journal app — SwiftUI + SwiftData. Record dreams via voice/text, AI interpretation, journal with filters, day/night dynamic theme.

## What's New in v0.0.2

### AI Dream Interpretation (Meaning Tab)
- **Jungian Analysis**: GPT-4o-mini powered dream interpretation with archetypal analysis, shadow work, symbolic breakdown
- **Structured Display**: Parsed markdown with section titles (16pt medium) and body text (subheadline), **bold** inline text, bullet points
- **5 UI States**:
  1. Empty text prompt (centered)
  2. Placeholder with EmotionJoyful icon + "Curious what it means?"
  3. Generating state with ProgressView
  4. Error state with retry button
  5. Scrollable interpretation with parsed sections
- **Smart Layout**: Empty states centered vertically between segment control and tab bar, interpretation text scrollable
- **Tab Bar Integration**: "Interpret Dream" button with InterpretIcon (orange SVG), appears only when text exists and no interpretation yet
- **DetailDreamState**: Observable coordinator pattern for DreamDetailView ↔ ReveriTabBar communication

### Backend
- **Edge Function**: `generate-dream-interpretation` — GPT-4o-mini (1500 tokens, temp 0.7), min 10 chars validation
- **Prompt**: Jungian framework (archetypes, shadow, anima/animus, collective unconscious), emotion context, 5-section structure
- **Deploy**: `~/bin/supabase functions deploy generate-dream-interpretation --project-ref bvydopjjndfgbhjczyis`

### Tech Improvements
- **iOS 26 Compliance**: Fixed Text `+` deprecation, use string interpolation pattern `Text("\(Text(...).style)\(Text(...).style)")`
- **SwiftData**: Added `Dream.interpretation: String?` field
- **Performance**: Empty states render outside ScrollView for proper centering, no unnecessary re-renders

## Previous Features (v0.0.1)

### Core Recording
- **Voice Recording**: 3-tier speech recognition (SpeechAnalyzer → SFSpeechRecognizer → WhisperKit stub)
- **Real-time Transcription**: Live captions with gradient-styled latest word, Russian punctuation post-processing
- **Audio Waveform**: Canvas + TimelineView 60fps rendering, playback scroll animation with skip sync
- **Voice → Text Flow**: Auto-switch to text mode if transcript exists, delete audio file
- **Recording Controls**: Stop/Pause with label migration animation, 3D flip on icon toggle
- **Review Mode**: Play/pause with skip ±5s, waveform playback animation, editable transcript

### AI Features
- **Title Generation**: GPT-4o-mini, 3-5 word concrete titles (not abstract), locale-aware prompts
- **Image Generation**: 2-stage pipeline (questions → art prompt → DALL-E), 74×74 thumbnail in detail view
- **Emotion Picker**: Post-save flow with HowDidItFeelCard, inline EmotionPickerGrid, staggered appear animation

### Journal & Filtering
- **Emotion Filter Bar**: MRU ordering, animated expand/collapse, glass effect with dimming
- **Tab Bar Integration**: Filter styling in journal tab (emotion color + icon + name)
- **Performance**: Cached `filteredDreams`, `localizedCaseInsensitiveContains()`, AudioAnalysisCache singleton
- **DreamCard**: Audio waveform player, EmotionTagBadge, options menu (rename/folder/share/delete)

### UI/UX
- **Liquid Glass Design**: `.reveriGlass()` modifier, GlassEffectContainer for adjacent elements
- **Theme**: Auto day/night switch (5-21h / 21-5h), ThemeManager @Observable
- **Cloud System**: 3-layer SVG shapes (Back/Mid/Front), mode switch pill at bottomTrailing
- **Custom Nav**: DreamDetailView with glass back/options buttons, segmented Dream/Meaning picker

### Architecture
- **Pure SwiftUI + Observation**: No Combine, no UIKit, `@State private var viewModel = ...` pattern
- **SwiftData**: Dream model with emotions array, imageURL, interpretation
- **Supabase**: Edge Functions for AI (title, questions, image, interpretation), 15s timeout
- **Speech Locale Picker**: 13 locales, persisted via @AppStorage, avatar circle menu in JournalHeader

## Known Issues
- SpeechAnalyzer unavailable on Simulator (falls back to SFSpeechRecognizer)
- Russian punctuation heuristics may fail on complex sentence structures
- No "Interpret Again" button (v1 limitation)

## Build
```bash
xcodebuild -scheme ReveriAI -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

Simulators: iPhone 17 Pro, iPhone 17 Pro Max, iPhone Air (iOS 26.1)

## Deploy Edge Functions
```bash
# Login first
~/bin/supabase login

# Deploy interpretation
~/bin/supabase functions deploy generate-dream-interpretation --project-ref bvydopjjndfgbhjczyis

# Deploy all functions
~/bin/supabase functions deploy --project-ref bvydopjjndfgbhjczyis
```

## Project Stats
- **12 files changed** in v0.0.2
- **538 insertions, 49 deletions**
- **4 new files**: DetailDreamState.swift, InterpretIcon asset, Edge Function, interpret_icon.svg
- **Edge Functions**: 4 total (title, questions, image, interpretation)

## Next Steps (v0.0.3)
- Folders organization
- Search functionality
- Time range filtering
- Dream export/sharing
- Offline mode improvements
- "Interpret Again" button

---

Built with SwiftUI + SwiftData + Supabase + OpenAI
