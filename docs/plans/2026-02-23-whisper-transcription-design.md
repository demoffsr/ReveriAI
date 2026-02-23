# Whisper Post-Recording Transcription

## Problem

Apple's on-device speech recognition (SpeechAnalyzer / SFSpeechRecognizer) produces poor quality Russian text — bad punctuation, missed words, silent resets. The resulting dream text is low quality, which cascades into poor AI title generation, interpretation, and image prompts.

## Solution

After saving an audio dream, send the .m4a file to OpenAI Whisper API via Supabase Edge Function for high-quality transcription. Keep live captions as-is for real-time UX feedback during recording.

## Scope

- Audio dreams only (not text-mode dreams)
- Whisper runs in background after save
- Both original (live captions) and Whisper transcripts stored separately
- User can toggle between them in DreamDetailView
- DreamCard shows "Обработка записи..." while pending

## Data Model Changes

`Dream.swift` — two new optional fields:

```swift
var whisperTranscript: String?    // Whisper API result (high quality)
var originalTranscript: String?   // Live captions result (original)
```

Status is computed, not stored:
- `audioFilePath != nil && whisperTranscript == nil` → transcribing
- `whisperTranscript != nil` → done
- No audioFilePath → not applicable

`dream.text` always holds the "best" text:
- Before Whisper: live captions text (or empty)
- After Whisper success: Whisper result
- After Whisper failure: falls back to originalTranscript

## Edge Function: `transcribe-audio`

Path: `supabase/functions/transcribe-audio/index.ts`

Input: multipart/form-data
- `file`: .m4a audio binary
- `locale`: speech locale code (e.g. "ru-RU")

Processing:
1. Extract file + locale from FormData
2. Build multipart request to `https://api.openai.com/v1/audio/transcriptions`
3. Parameters: `model: "whisper-1"`, `language` from locale (first 2 chars), `response_format: "text"`, contextual `prompt` per language
4. Return `{ transcript: "..." }`

Russian prompt: "Это запись сна, рассказанная утром после пробуждения."
English prompt: "This is a dream recording narrated in the morning after waking up."

## iOS: DreamAIService

New methods:

```swift
static func transcribeAudio(fileURL: URL, locale: SpeechLocale) async throws -> String
```

- Reads .m4a file as Data
- Builds multipart/form-data request (raw URLSession, not Supabase SDK)
- URL: `SupabaseConfig.projectURL + "/functions/v1/transcribe-audio"`
- Auth: `Authorization: Bearer <anon_key>`
- Timeout: 120 seconds (dedicated URLSession)
- Returns transcript string

```swift
static func transcribeAudioInBackground(
    dreamID: PersistentIdentifier,
    audioFileName: String,
    locale: SpeechLocale,
    modelContainer: ModelContainer
)
```

- Resolves file path from `Documents/recordings/{audioFileName}`
- Calls `transcribeAudio(fileURL:locale:)`
- Updates `dream.text`, `dream.whisperTranscript`
- If `dream.title.isEmpty` → triggers `generateTitleInBackground`
- On failure: sets `dream.text = dream.originalTranscript ?? ""`

## UI: DreamDetailView

When `dream.whisperTranscript != nil && dream.originalTranscript != nil`:
- `@State private var showingOriginal = false`
- Shows either original or Whisper text based on toggle
- Inline text button "Оригинал" (gray, 12pt) right after last word of text
- Tapping toggles to original, button changes to "Whisper"

## UI: DreamCard

- While transcribing (`audioFilePath != nil && text.isEmpty && whisperTranscript == nil`): show "Обработка записи..." in gray italic with pulse animation
- After Whisper: normal `dream.text` preview (2 lines)
- No toggle button in card — only in detail view

## Save Flow

In `RecordViewModel.saveAudioDream()`:
1. `dream.text = transcript` (live captions, may be empty)
2. `dream.originalTranscript = transcript.isEmpty ? nil : transcript`
3. After `context.save()`, launch `DreamAIService.transcribeAudioInBackground(dreamID:audioFileName:locale:container:)`

## Deploy

```bash
~/bin/supabase functions deploy transcribe-audio --project-ref bvydopjjndfgbhjczyis
```
