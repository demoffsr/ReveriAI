# ReveriAI — Performance Patterns

Reference for caching strategies, rendering optimizations, and memory management.
Load this file when optimizing performance, adding new cached state, or working with Canvas/waveform.

---

## General Principles

- **Canvas performance:** For high-frequency data (waveform bars), use a plain class buffer (`@State private var buffer = MyBuffer()`) instead of `@State` arrays. Class mutations don't trigger SwiftUI diffs. Only `TimelineView` drives redraws.
- **Performance patterns:** Cache expensive computations in ViewModel instead of computed properties in views. Use `.onChange()` to update cached values only when dependencies change. Avoid `.lowercased()` string allocations in hot paths — prefer Foundation's `.localizedCaseInsensitiveContains()`. For repeated file I/O (audio analysis), use singleton cache with deduplication. Use `indices` instead of `Array(enumerated())` to avoid intermediate allocations. Use `reduce` instead of `for`-loop with mutable `var` for collection concatenation (Text, arrays). Use `.drawingGroup()` for expensive rendering (blur effects, large images, Canvas with many elements) to render into Metal texture once instead of per-frame. Store fire-and-forget Tasks in `@State` and cancel on dismiss/tab-switch to prevent state updates after view dismissal. Example: `filteredDreams` cached in ViewModel with selective updates vs computed property that runs on every render.

## Component-Specific Optimizations

- **Image caching:** `ImageCache.shared` (NSCache, 50 MB limit) + `CachedAsyncImage` view for AI-generated dream images. Deduplicates in-flight requests, prevents re-downloading on scroll/navigation.
- **Dream.emotions caching:** `@Transient` cached property with equality check on `emotionValues` — `compactMap` runs only when array changes, not on every access.
- **FolderCard.topEmotions caching:** `@State cachedEmotions` updated via `.task(id: folder.dreams.count)` — O(n×m) emotion counting runs only when dream count changes.
- **FolderDetailView.filteredDreams caching:** `@State cachedFilteredDreams` updated via `.onChange(of: searchText)` and `.onChange(of: folder.dreams.count)` — sort+filter not run on every render.
- **AddDreamsToFolderSheet.filteredDreams caching:** `@State cachedFilteredDreams` with 300ms debounce via cancellable `Task` — ~80% reduction in filter operations during search typing.
- **DreamDetailView interpretation parsing:** Regex-based markdown parsing cached in `@State cachedInterpretationSections`, updated in `onAppear` and `onChange(of: detailState.hasInterpretation)` — not run on every body evaluation.
- **DreamDetailView.boldInlineText:** Uses `reduce` instead of `for`-loop for Text concatenation — avoids N intermediate Text object allocations when parsing **bold** markers.
- **DateFormatter reuse:** `private static let` formatters in `Date+Helpers` — created once, reused across all DreamCard/DreamDetailView renders.
- **SwiftData indexing:** `#Index<Dream>([\.createdAt])` for sort/filter performance with 100+ dreams.
- **CelestialIcon.drawingGroup:** Blur effects (outer/inner rings) wrapped in `.drawingGroup()` — renders to Metal texture once instead of per-frame off-screen rendering. Critical for RecordView where waveform animates @ 60fps.
- **DreamHeader.drawingGroup:** Entire composite (1.3MB background image + gradient + 50 stars Canvas) rendered to off-screen Metal texture once via `.drawingGroup()` on root ZStack — prevents re-composition on every frame.
- **ReveriTabBar observation isolation:** `DetailDreamControlsView` wrapper isolates `detailState` observation — only wrapper rebuilds on `DetailDreamState` changes, not entire TabBar. Pattern: same as `LiveWaveformView` for `audioRecorder.currentLevel`.
- **Timer lifecycle:** `AudioRecorder` and `DreamCardPlayer` playback timers use `guard let self else { break }` to exit loop on deinit — prevents infinite background loops when `self` deallocates.
- **Task cancellation:** `RootView.dismissTask` stored in `@State`, cancelled on tab switch via `.onChange(of: selectedTab)` and on re-invocation — prevents fire-and-forget Task from updating state after view dismissal.
- **ThemeManager background pause:** Timer stops on `didEnterBackgroundNotification`, resumes on `willEnterForegroundNotification` — no battery drain when app not visible.
- **Search debounce:** `JournalView` search debounced 300ms via cancellable `Task` — filtering runs after typing pause, not on every keystroke.
- **Speech recognition constants:** `SpeechRecognitionService.fillers` and `.questionWords` are `private static let` — Set literals created once, not on every `punctuateSegment()` call.
- **CardWaveformView.unplayedBarColor:** `Color(hex: "C3C3C3")` extracted to `private static let` — hex parsing (Scanner + bit shifting) runs once at type load, not every ~100ms during playback.
- **DreamCard cached values:** `displayTitle` and `audioURL` cached in `@State`, computed in `onAppear`/`onChange`. `recordingsDirectory` is `static let`. Eliminates FileManager I/O and split/join on every scroll render.
- **FolderPickerSheet.filteredFolders caching:** `@State cachedFilteredFolders` with 300ms debounce via cancellable `Task` — consistent with FolderDetailView and AddDreamsToFolderSheet patterns.
