# Plan: Infinite Captions + Editable After Stop

## Current State Analysis

### Live Captions (during recording)
- **Location:** `RecordView.swift`, `voicePlaceholder` computed property (lines 292-348)
- **Layout:** `ScrollView` containing either placeholder text or `liveCaptionsText` (a `Text` view with gradient styling on the last word)
- **Scrolling:** The `ScrollView` has no `lineLimit` or fixed height constraint — it can scroll freely. However, it lacks `.defaultScrollAnchor(.bottom)` which means it does NOT auto-scroll to the bottom as new text appears. This should be added.
- **No clipping issue found** — the `ScrollView` itself is unbounded vertically. The only constraint is `.padding(.bottom, 100)` for tab bar clearance. Captions should already scroll infinitely.
- **Potential issue:** The `ScrollView` wraps the entire voice placeholder content (waveform + captions). If the waveform is inside the same `ScrollView`, scrolling might feel off. Looking at the code: the waveform (`LiveWaveformView`) is **outside** the `ScrollView` — it's a sibling in the `VStack`. The `ScrollView` only contains the captions text. This is correct.

### After Stop (handleStop, lines 386-421)
- When recording stops with a transcript: text is copied to `viewModel.dreamText`, mode switches to `.text`, audio is deleted, speech service is reset. User enters **text mode** (TextModeView with TextEditor).
- When recording stops without transcript: enters **review mode** (`isReviewing = true`). Review mode shows frozen waveform + captions (read-only `Text`), with Preview/Delete in tab bar and Save Dream button in cloud layer.
- **Problem:** In review mode, the captions are still rendered as a plain `Text` view (not editable). The user requirement is to make them editable IN PLACE during review mode, without switching to text mode.

### Review Mode UI (current)
- Cloud layer shows: review timer (bottomLeading) + Save Dream button (bottomTrailing)
- Tab bar shows: Preview (play/pause) + Delete
- Content area: frozen waveform + read-only captions in `voicePlaceholder`
- Save audio dream uses `speechService.transcribedText` for the transcript — NOT `viewModel.dreamText`

## Changes Required

### File: `RecordView.swift`

#### 1. Add `.defaultScrollAnchor(.bottom)` to captions ScrollView
This ensures live captions auto-scroll to bottom during recording.

**In `voicePlaceholder` (line 342-343), change:**
```swift
.scrollIndicators(.hidden)
```
**To:**
```swift
.scrollIndicators(.hidden)
.defaultScrollAnchor(.bottom)
```

#### 2. Add `@State` for editable review text
Add a new state property to hold the editable transcript during review mode:
```swift
@State private var reviewText: String = ""
```

#### 3. Populate `reviewText` when entering review mode
In `handleStop()`, when there IS a transcript but we still enter review mode (or: change flow so transcript also enters review mode), copy the transcript:

**Current flow issue:** Right now, if transcript exists → switches to text mode. But the requirement says editing should happen IN review mode (voice mode). We need to change the flow:
- When recording stops with a transcript: stay in voice mode, enter review mode, populate `reviewText` with the transcript. Keep the audio file (don't delete it).
- When recording stops without transcript: enter review mode with empty `reviewText`.

**Modified `handleStop()`:**
```swift
private func handleStop() {
    let url = audioRecorder.stopRecording()
    speechService.stopTranscription()
    timerTask?.cancel()
    timerTask = nil

    guard elapsedSeconds > 1 else {
        audioRecorder.deleteRecording()
        speechService.resetTranscription()
        elapsedSeconds = 0
        return
    }

    let transcript = speechService.transcribedText
        .trimmingCharacters(in: .whitespacesAndNewlines)

    // Always enter review mode if we have a recording
    if url != nil {
        reviewText = transcript
        totalRecordingSeconds = elapsedSeconds
        withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
            isReviewing = true
        }
    } else if !transcript.isEmpty {
        // No audio file but have transcript — fall back to text mode
        viewModel.dreamText = transcript
        viewModel.mode = .text
        speechService.resetTranscription()
        elapsedSeconds = 0
        totalRecordingSeconds = 0
    } else {
        speechService.resetTranscription()
        elapsedSeconds = 0
    }
}
```

#### 4. Make captions editable in review mode
In `voicePlaceholder`, after the waveform, show:
- During **recording**: read-only `Text` with live gradient captions (current behavior)
- During **review**: editable `TextEditor` bound to `reviewText`

**Replace the `ScrollView` block in `voicePlaceholder` with:**
```swift
if isReviewing {
    // Editable captions in review mode
    TextEditor(text: $reviewText)
        .font(.system(size: 15))
        .tracking(-0.23)
        .lineSpacing(5)
        .tint(theme.accent)
        .scrollContentBackground(.hidden)
        .padding(.bottom, 100)
        .overlay(alignment: .topLeading) {
            if reviewText.isEmpty {
                Text("Add dream description...")
                    .font(.system(size: 15))
                    .tracking(-0.23)
                    .foregroundStyle(.black.opacity(0.3))
                    .allowsHitTesting(false)
            }
        }
} else {
    ScrollView {
        // ... existing live captions code ...
    }
    .scrollIndicators(.hidden)
    .defaultScrollAnchor(.bottom)
    .padding(.bottom, 100)
}
```

#### 5. Wire `reviewText` to save
In `handleSaveAudio()`, use `reviewText` instead of `speechService.transcribedText`:

**Change line 433:**
```swift
let transcript = speechService.transcribedText.trimmingCharacters(in: .whitespacesAndNewlines)
```
**To:**
```swift
let transcript = reviewText.trimmingCharacters(in: .whitespacesAndNewlines)
```

#### 6. Reset `reviewText` on delete/cleanup
In `handleDelete()` (line 423), add:
```swift
reviewText = ""
```

In `handleSaveAudio()`, after saving, add:
```swift
reviewText = ""
```

#### 7. Enable Save Dream button when reviewText has content
Currently the Save Dream button in review mode is always visible (cloud layer, line 191). It should probably be conditionally shown based on whether there's text or audio. Since we always have audio in review mode, it can stay always visible. No change needed here.

### File: `RecordViewModel.swift`
No changes needed. The `reviewText` lives as `@State` in `RecordView` since it's tied to the recording lifecycle, not the ViewModel's text mode.

### File: `RootView.swift`
No changes needed. The review mode state machine remains the same.

### File: `ReveriTabBar.swift`
No changes needed. Review controls (Preview + Delete) remain the same.

### File: `SpeechRecognitionService.swift`
No changes needed. The service's text properties are only read; we copy the transcript to `reviewText` at stop time.

## Step-by-Step Implementation

1. **Add `@State private var reviewText: String = ""` to `RecordView`** (near line 15, with other state properties)

2. **Add `.defaultScrollAnchor(.bottom)` to the captions `ScrollView`** in `voicePlaceholder` (after `.scrollIndicators(.hidden)` on line 343)

3. **Modify `handleStop()`** to always enter review mode when there's a recording URL, populating `reviewText` with the transcript (don't switch to text mode, don't delete audio)

4. **Split the `ScrollView` in `voicePlaceholder`** into two branches:
   - `isReviewing` → `TextEditor(text: $reviewText)` with matching font/tracking/lineSpacing
   - else → existing `ScrollView` with live captions

5. **Update `handleSaveAudio()`** to use `reviewText` instead of `speechService.transcribedText`

6. **Add `reviewText = ""` cleanup** in `handleDelete()` and `handleSaveAudio()`

## Edge Cases & Concerns

1. **Keyboard handling in review mode:** When the user taps the TextEditor to edit, the keyboard appears. The view already has `.ignoresSafeArea(.keyboard)` on the root ZStack in `RootView`. The TextEditor is inside a VStack that doesn't animate for keyboard — this should be fine since the text area is scrollable.

2. **Empty transcript:** If speech recognition produced nothing, `reviewText` will be empty. The TextEditor shows a placeholder. User can type manually. Save button is always visible in review mode (saves audio + whatever text exists).

3. **Audio playback during editing:** User can tap Preview in the tab bar to play audio while editing text. No conflict — these are independent.

4. **Text mode pill:** The mode switch pill is hidden during recording and review (`!isRecording` and `!isReviewing` guards on line 197). No change needed.

5. **`speechService.resetTranscription()` timing:** Currently called in `handleDelete()`. Should also be called when entering review mode after populating `reviewText`, to free memory. Add `speechService.resetTranscription()` at the end of the review-mode branch in `handleStop()`.

6. **Backwards compatibility of saved dreams:** `saveAudioDream` already accepts a `transcript` parameter. Using `reviewText` is a drop-in replacement. No model changes needed.
