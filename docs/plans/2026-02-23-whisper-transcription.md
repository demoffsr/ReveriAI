# Whisper Post-Recording Transcription — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** After saving an audio dream, send the .m4a file to OpenAI Whisper API via Supabase Edge Function for high-quality transcription, replacing poor Apple Speech output.

**Architecture:** New Edge Function `transcribe-audio` accepts multipart audio + locale, forwards to OpenAI Whisper API. iOS side: new methods in `DreamAIService` handle upload and background Dream model update. DreamDetailView gets an inline toggle between Whisper and original text. DreamCard shows a placeholder while transcription is pending.

**Tech Stack:** Deno (Edge Function), OpenAI Whisper API, Swift/SwiftUI, SwiftData, URLSession multipart

---

### Task 1: Dream Model — Add New Fields

**Files:**
- Modify: `ReveriAI/Models/Dream.swift`

**Step 1: Add `whisperTranscript` and `originalTranscript` fields**

In `Dream.swift`, add two new optional String properties after `interpretation`:

```swift
var whisperTranscript: String?
var originalTranscript: String?
```

Add corresponding `init` parameters (both default `nil`):

```swift
init(
    text: String,
    title: String = "",
    emotions: [DreamEmotion] = [],
    createdAt: Date = .now,
    audioFilePath: String? = nil,
    imageURL: String? = nil,
    isTranslated: Bool = false,
    whisperTranscript: String? = nil,
    originalTranscript: String? = nil
) {
    // ... existing code ...
    self.whisperTranscript = whisperTranscript
    self.originalTranscript = originalTranscript
}
```

Add a computed property for transcription status:

```swift
var isTranscribingAudio: Bool {
    audioFilePath != nil && whisperTranscript == nil
}

var hasTranscriptToggle: Bool {
    whisperTranscript != nil && originalTranscript != nil
}
```

**Step 2: Build to verify SwiftData migration works**

Run: `xcodebuild -scheme ReveriAI -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: BUILD SUCCEEDED (SwiftData lightweight migration handles new optional fields automatically)

**Step 3: Commit**

```bash
git add ReveriAI/Models/Dream.swift
git commit -m "feat: add whisperTranscript and originalTranscript fields to Dream model"
```

---

### Task 2: Edge Function — `transcribe-audio`

**Files:**
- Create: `supabase/functions/transcribe-audio/index.ts`

**Step 1: Create the Edge Function**

Create `supabase/functions/transcribe-audio/index.ts`:

```typescript
import "jsr:@supabase/functions-js/edge-runtime.d.ts"

const corsHeaders = {
  'Content-Type': 'application/json',
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), { status: 405, headers: corsHeaders })
  }

  const authHeader = req.headers.get('Authorization')
  if (!authHeader) {
    return new Response(JSON.stringify({ error: 'Missing authorization' }), { status: 401, headers: corsHeaders })
  }

  const contentType = req.headers.get('Content-Type') || ''

  // Support both multipart/form-data and raw binary with locale in header
  let audioData: Uint8Array
  let locale: string

  if (contentType.includes('multipart/form-data')) {
    const formData = await req.formData()
    const file = formData.get('file')
    locale = (formData.get('locale') as string) || 'en-US'

    if (!file || !(file instanceof File)) {
      return new Response(JSON.stringify({ error: 'Missing audio file' }), { status: 400, headers: corsHeaders })
    }

    audioData = new Uint8Array(await file.arrayBuffer())
  } else {
    // Raw binary body, locale from header
    locale = req.headers.get('X-Locale') || 'en-US'
    audioData = new Uint8Array(await req.arrayBuffer())
  }

  if (audioData.length === 0) {
    return new Response(JSON.stringify({ error: 'Empty audio data' }), { status: 400, headers: corsHeaders })
  }

  const openaiKey = Deno.env.get('OPENAI_API_KEY')
  if (!openaiKey) {
    return new Response(JSON.stringify({ error: 'OpenAI key not configured' }), { status: 500, headers: corsHeaders })
  }

  const language = locale.substring(0, 2).toLowerCase()
  const isRussian = language === 'ru'
  const prompt = isRussian
    ? 'Это запись сна, рассказанная утром после пробуждения.'
    : 'This is a dream recording narrated in the morning after waking up.'

  // Build multipart form for OpenAI Whisper API
  const formData = new FormData()
  formData.append('file', new Blob([audioData], { type: 'audio/mp4' }), 'recording.m4a')
  formData.append('model', 'whisper-1')
  formData.append('language', language)
  formData.append('response_format', 'text')
  formData.append('prompt', prompt)

  const response = await fetch('https://api.openai.com/v1/audio/transcriptions', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${openaiKey}`,
    },
    body: formData,
  })

  if (!response.ok) {
    const error = await response.text()
    return new Response(JSON.stringify({ error: `Whisper error: ${error}` }), { status: 502, headers: corsHeaders })
  }

  // response_format=text returns plain text, not JSON
  const transcript = (await response.text()).trim()

  return new Response(JSON.stringify({ transcript }), { headers: corsHeaders })
})
```

**Step 2: Deploy the Edge Function**

Run: `~/bin/supabase functions deploy transcribe-audio --project-ref bvydopjjndfgbhjczyis`
Expected: Deployed successfully

**Step 3: Test with curl**

Run (with a small test .m4a file):
```bash
curl -X POST \
  'https://bvydopjjndfgbhjczyis.supabase.co/functions/v1/transcribe-audio' \
  -H 'Authorization: Bearer <anon_key>' \
  -F 'file=@test_recording.m4a' \
  -F 'locale=ru-RU'
```
Expected: `{"transcript":"..."}`

**Step 4: Commit**

```bash
git add supabase/functions/transcribe-audio/index.ts
git commit -m "feat: add transcribe-audio Edge Function (Whisper API)"
```

---

### Task 3: iOS — DreamAIService Transcription Methods

**Files:**
- Modify: `ReveriAI/Services/DreamAIService.swift`

**Step 1: Add `transcribeAudio` method**

Add to `DreamAIService` enum, after the existing `generateTitle` method:

```swift
static func transcribeAudio(fileURL: URL, locale: SpeechLocale) async throws -> String {
    let audioData = try Data(contentsOf: fileURL)
    guard !audioData.isEmpty else {
        throw Error.emptyText
    }

    let boundary = UUID().uuidString
    let url = URL(string: "\(SupabaseConfig.projectURL)/functions/v1/transcribe-audio")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
    request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

    var body = Data()
    // File field
    body.append("--\(boundary)\r\n".data(using: .utf8)!)
    body.append("Content-Disposition: form-data; name=\"file\"; filename=\"recording.m4a\"\r\n".data(using: .utf8)!)
    body.append("Content-Type: audio/mp4\r\n\r\n".data(using: .utf8)!)
    body.append(audioData)
    body.append("\r\n".data(using: .utf8)!)
    // Locale field
    body.append("--\(boundary)\r\n".data(using: .utf8)!)
    body.append("Content-Disposition: form-data; name=\"locale\"\r\n\r\n".data(using: .utf8)!)
    body.append("\(locale.rawValue)\r\n".data(using: .utf8)!)
    body.append("--\(boundary)--\r\n".data(using: .utf8)!)
    request.httpBody = body

    // Dedicated session with 120s timeout for long recordings
    let config = URLSessionConfiguration.default
    config.timeoutIntervalForRequest = 120
    let session = URLSession(configuration: config)

    let (data, response) = try await session.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
        let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
        throw Error.networkError(NSError(domain: "WhisperAPI", code: (response as? HTTPURLResponse)?.statusCode ?? 0, userInfo: [NSLocalizedDescriptionKey: errorText]))
    }

    struct TranscriptResponse: Decodable {
        let transcript: String
    }

    let decoded = try JSONDecoder().decode(TranscriptResponse.self, from: data)
    guard !decoded.transcript.isEmpty else {
        throw Error.emptyText
    }

    return decoded.transcript
}
```

**Step 2: Add `transcribeAudioInBackground` method**

Add after the above method:

```swift
private static let recordingsDirectory: URL = {
    FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("recordings")
}()

static func transcribeAudioInBackground(
    dreamID: PersistentIdentifier,
    audioFileName: String,
    locale: SpeechLocale,
    modelContainer: ModelContainer
) {
    Task { @MainActor in
        let fileURL = recordingsDirectory.appendingPathComponent(audioFileName)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            logger.error("Audio file not found: \(audioFileName)")
            return
        }

        do {
            let transcript = try await transcribeAudio(fileURL: fileURL, locale: locale)
            let context = modelContainer.mainContext
            guard let dream = context.model(for: dreamID) as? Dream else {
                logger.warning("Dream not found for Whisper update")
                return
            }
            dream.whisperTranscript = transcript
            dream.text = transcript
            try context.save()
            logger.info("Whisper transcription saved (\(transcript.count) chars)")

            // Generate title from high-quality Whisper text
            if dream.title.isEmpty {
                generateTitleInBackground(
                    dreamID: dreamID,
                    dreamText: transcript,
                    locale: locale,
                    modelContainer: modelContainer
                )
            }
        } catch {
            logger.error("Whisper transcription failed: \(error.localizedDescription)")
            // Fallback: ensure dream.text has the original transcript
            let context = modelContainer.mainContext
            if let dream = context.model(for: dreamID) as? Dream,
               dream.text.isEmpty,
               let original = dream.originalTranscript {
                dream.text = original
                try? context.save()
            }
        }
    }
}
```

**Step 3: Build to verify compilation**

Run: `xcodebuild -scheme ReveriAI -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add ReveriAI/Services/DreamAIService.swift
git commit -m "feat: add Whisper transcription methods to DreamAIService"
```

---

### Task 4: Save Flow — Trigger Whisper After Audio Save

**Files:**
- Modify: `ReveriAI/Features/Record/RecordViewModel.swift`

**Step 1: Update `saveAudioDream` to store originalTranscript and trigger Whisper**

Replace the `saveAudioDream` method:

```swift
func saveAudioDream(audioPath: String, transcript: String = "", context: ModelContext) {
    let trimmedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
    let dream = Dream(
        text: trimmedTranscript,
        emotions: selectedEmotions,
        audioFilePath: audioPath,
        originalTranscript: trimmedTranscript.isEmpty ? nil : trimmedTranscript
    )
    context.insert(dream)
    try? context.save()
    HapticService.notification(.success)

    let locale = SpeechLocale(rawValue: speechLocaleRaw) ?? .russian

    // Title from live captions (will be overwritten after Whisper if empty)
    if !trimmedTranscript.isEmpty {
        DreamAIService.generateTitleInBackground(
            dreamID: dream.persistentModelID,
            dreamText: trimmedTranscript,
            locale: locale,
            modelContainer: context.container
        )
    }

    // Whisper transcription in background
    DreamAIService.transcribeAudioInBackground(
        dreamID: dream.persistentModelID,
        audioFileName: audioPath,
        locale: locale,
        modelContainer: context.container
    )

    savedDream = dream
    onDreamSaved?(dream)
    state = .saved
    NotificationService.removeDeliveredNotifications()
    onShowHowDidItFeel?()
}
```

**Step 2: Build**

Run: `xcodebuild -scheme ReveriAI -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add ReveriAI/Features/Record/RecordViewModel.swift
git commit -m "feat: trigger Whisper transcription on audio dream save"
```

---

### Task 5: UI — DreamCard Transcription Placeholder

**Files:**
- Modify: `ReveriAI/Features/Journal/DreamCard.swift`

**Step 1: Add transcription pending placeholder**

Find the text preview section in DreamCard (the `if !dream.text.isEmpty { Text(dream.text)... }` block). Replace it with:

```swift
if !dream.text.isEmpty {
    Text(dream.text)
        .font(.system(size: 13))
        .foregroundStyle(.black.opacity(0.5))
        .lineLimit(2)
} else if dream.isTranscribingAudio {
    Text("Обработка записи...")
        .font(.system(size: 13).italic())
        .foregroundStyle(.black.opacity(0.35))
        .phaseAnimator([false, true]) { content, phase in
            content.opacity(phase ? 0.4 : 1.0)
        } animation: { _ in
            .easeInOut(duration: 1.2)
        }
}
```

Also add `onChange(of: dream.whisperTranscript)` alongside the existing `onChange(of: dream.title)` to trigger `updateCachedValues()` when Whisper finishes.

**Step 2: Build**

Run: `xcodebuild -scheme ReveriAI -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add ReveriAI/Features/Journal/DreamCard.swift
git commit -m "feat: show transcription placeholder in DreamCard while Whisper is processing"
```

---

### Task 6: UI — DreamDetailView Toggle

**Files:**
- Modify: `ReveriAI/Features/Journal/DreamDetailView.swift`

**Step 1: Add state variable**

Add to the `@State` section of `DreamDetailView`:

```swift
@State private var showingOriginal = false
```

**Step 2: Replace dream text display in the `.dream` case**

Replace the current `case .dream:` block (lines 99-104) with:

```swift
case .dream:
    dreamTextContent
```

**Step 3: Add `dreamTextContent` computed property**

Add a new private computed property:

```swift
@ViewBuilder
private var dreamTextContent: some View {
    let displayText = showingOriginal
        ? (dream.originalTranscript ?? dream.text)
        : dream.text

    if displayText.isEmpty && dream.isTranscribingAudio {
        VStack(spacing: 12) {
            ProgressView()
            Text("Обработка записи...")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    } else {
        VStack(alignment: .leading, spacing: 0) {
            // Dream text with inline toggle button
            let textView = Text(displayText)
                .font(.system(size: 15))
                .lineSpacing(4)
                .tracking(-0.23)
                .foregroundStyle(.black.opacity(0.8))

            if dream.hasTranscriptToggle {
                // Text + inline toggle button
                (textView + Text("  ") + Text(showingOriginal ? "Whisper" : "Оригинал")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary))
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showingOriginal.toggle()
                        }
                    }
            } else {
                textView
            }
        }
    }
}
```

Note: The `Text + Text` concatenation is used here within a `View` context, not standalone — it produces a tappable combined text. However, per the project convention about `Text + Text` being deprecated in iOS 26, we should use an alternative approach. Since we need the entire combined text to be tappable (to toggle), and inline `Text` interpolation doesn't support tapping individual segments, use a `HStack` with `.lastTextBaseline` alignment instead:

```swift
@ViewBuilder
private var dreamTextContent: some View {
    let displayText = showingOriginal
        ? (dream.originalTranscript ?? dream.text)
        : dream.text

    if displayText.isEmpty && dream.isTranscribingAudio {
        VStack(spacing: 12) {
            ProgressView()
            Text("Обработка записи...")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    } else {
        VStack(alignment: .leading, spacing: 0) {
            Text(displayText)
                .font(.system(size: 15))
                .lineSpacing(4)
                .tracking(-0.23)
                .foregroundStyle(.black.opacity(0.8))

            if dream.hasTranscriptToggle {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showingOriginal.toggle()
                    }
                } label: {
                    Text(showingOriginal ? "Whisper" : "Оригинал")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)
            }
        }
    }
}
```

This puts the toggle button on a line below the text. To make it truly inline after the last word, the implementer should try the `Text + Text` interpolation approach first and fall back to this if the iOS 26 deprecation causes issues. The key constraint from the user: "рядом с последним словом" — after the last word of text.

**Step 4: Build**

Run: `xcodebuild -scheme ReveriAI -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: BUILD SUCCEEDED

**Step 5: Commit**

```bash
git add ReveriAI/Features/Journal/DreamDetailView.swift
git commit -m "feat: add Whisper/Original transcript toggle in DreamDetailView"
```

---

### Task 7: Deploy and End-to-End Test

**Step 1: Deploy Edge Function**

Run: `~/bin/supabase functions deploy transcribe-audio --project-ref bvydopjjndfgbhjczyis`
Expected: Function deployed

**Step 2: Build and run on simulator**

Run: `xcodebuild -scheme ReveriAI -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`

**Step 3: Manual test flow**

1. Open app → Record tab → Record a voice dream (speak for ~10 seconds)
2. Stop recording → Review screen appears
3. Save audio dream
4. Check Journal → DreamCard should show "Обработка записи..." pulse animation
5. Wait ~5-15 seconds → DreamCard should update with Whisper text
6. Tap card → DreamDetailView → verify text is from Whisper
7. Check that "Оригинал" button appears after last word
8. Tap "Оригинал" → text switches to live captions version, button changes to "Whisper"
9. Tap "Whisper" → back to high-quality text
10. Verify title was generated from Whisper text

**Step 4: Final commit**

```bash
git add -A
git commit -m "feat: complete Whisper post-recording transcription pipeline"
```
