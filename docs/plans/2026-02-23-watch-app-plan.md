# Apple Watch App — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a watchOS companion app for quick voice-based dream recording with emotion selection, syncing to the iPhone app via SwiftData + CloudKit.

**Architecture:** Watch records audio via AVAudioRecorder, saves a Dream stub (empty text, selected emotion) to SwiftData. Audio file is transferred to iPhone via WatchConnectivity `transferFile()`. iPhone receives audio, runs speech recognition, updates Dream.text — CloudKit syncs it back. Complication provides quick launch from watch face.

**Tech Stack:** SwiftUI (watchOS), SwiftData + CloudKit, AVFoundation (audio), WatchConnectivity, WidgetKit (complication)

**Existing Watch target:** `Reveri Watch App/` folder, scheme `Reveri Watch App`, entry point `ReveriApp.swift`

---

### Task 1: Configure SwiftData + CloudKit for Both Targets

**Files:**
- Modify: `ReveriAI/ReveriAIApp.swift` (add CloudKit ModelConfiguration)
- Modify: `Reveri Watch App/ReveriApp.swift` (add ModelContainer with same config)
- Shared: `ReveriAI/Models/Dream.swift`, `DreamEmotion.swift`, `DreamFolder.swift` (add Watch target membership)

**Context:**
- Current ModelContainer: `try ModelContainer(for: Dream.self, DreamFolder.self)` — no CloudKit
- CloudKit requires: iCloud entitlement + CloudKit container on both targets
- SwiftData auto-syncs via CloudKit when `ModelConfiguration` has `cloudKitDatabase: .automatic`

**Step 1: Add iCloud + CloudKit entitlement to both targets**

In Xcode manually (cannot be done via code):
1. Select **ReveriAI** target → Signing & Capabilities → + Capability → iCloud
2. Check **CloudKit**, create container `iCloud.com.reveri.ReveriAI`
3. Select **Reveri Watch App** target → same steps, same container
4. This creates/updates `.entitlements` files

**Step 2: Add shared model files to Watch target membership**

In Xcode File Inspector, add **Reveri Watch App** target membership to:
- `ReveriAI/Models/Dream.swift`
- `ReveriAI/Models/DreamEmotion.swift`
- `ReveriAI/Models/DreamFolder.swift`
- `ReveriAI/Extensions/Color+Hex.swift`

**Step 3: Update iPhone ModelContainer for CloudKit**

In `ReveriAIApp.swift`, change ModelContainer creation:

```swift
// Before:
let container = try ModelContainer(for: Dream.self, DreamFolder.self)

// After:
let config = ModelConfiguration(
    cloudKitDatabase: .automatic
)
let container = try ModelContainer(
    for: Dream.self, DreamFolder.self,
    configurations: config
)
```

**Step 4: Setup Watch app entry point with ModelContainer**

Replace `Reveri Watch App/ReveriApp.swift`:

```swift
import SwiftUI
import SwiftData

@main
struct ReveriWatchApp: App {
    var body: some Scene {
        WindowGroup {
            WatchRecordingView()
        }
        .modelContainer(for: [Dream.self, DreamFolder.self], isAutosaveEnabled: true)
    }
}
```

Note: Watch uses `.modelContainer()` scene modifier (simpler than iPhone's deferred init). CloudKit syncs automatically with same container ID.

**Step 5: Build both targets to verify compilation**

```bash
xcodebuild -scheme ReveriAI -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
xcodebuild -scheme "Reveri Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)' build
```

**Step 6: Commit**

```bash
git add -A
git commit -m "feat(watch): configure SwiftData + CloudKit for Watch app"
```

---

### Task 2: Watch Audio Recorder

**Files:**
- Create: `Reveri Watch App/Services/WatchAudioRecorder.swift`

**Context:**
- iPhone uses AVAudioEngine with tapped buffers → complex, overkill for Watch
- Watch needs simple AVAudioRecorder → save .m4a file
- Audio format must be compatible with iPhone's SpeechRecognitionService (AAC m4a works)
- Need current audio level for waveform visualization

**Step 1: Create WatchAudioRecorder**

```swift
import AVFoundation
import Observation

@Observable
final class WatchAudioRecorder {
    var isRecording = false
    var currentLevel: Float = 0  // 0...1 for waveform
    var duration: TimeInterval = 0
    var audioFilePath: String?

    private var recorder: AVAudioRecorder?
    private var timer: Timer?

    func startRecording() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .default)
        try session.setActive(true)

        let fileName = "dream_\(Int(Date().timeIntervalSince1970)).m4a"
        let url = Self.recordingsDirectory.appendingPathComponent(fileName)

        try FileManager.default.createDirectory(
            at: Self.recordingsDirectory,
            withIntermediateDirectories: true
        )

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder?.isMeteringEnabled = true
        recorder?.record()

        audioFilePath = fileName
        isRecording = true
        duration = 0

        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, let recorder = self.recorder else { return }
            recorder.updateMeters()
            let power = recorder.averagePower(forChannel: 0)
            // Normalize: -60dB...0dB → 0...1
            let linear = max(0, min(1, (power + 60) / 60))
            self.currentLevel = linear
            self.duration = recorder.currentTime
        }
    }

    func stopRecording() {
        recorder?.stop()
        recorder = nil
        timer?.invalidate()
        timer = nil
        isRecording = false

        try? AVAudioSession.sharedInstance().setActive(false)
    }

    func deleteRecording() {
        guard let path = audioFilePath else { return }
        let url = Self.recordingsDirectory.appendingPathComponent(path)
        try? FileManager.default.removeItem(at: url)
        audioFilePath = nil
    }

    var audioFileURL: URL? {
        guard let path = audioFilePath else { return nil }
        return Self.recordingsDirectory.appendingPathComponent(path)
    }

    static var recordingsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("recordings")
    }
}
```

**Step 2: Build Watch target**

```bash
xcodebuild -scheme "Reveri Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)' build
```

**Step 3: Commit**

```bash
git add "Reveri Watch App/Services/WatchAudioRecorder.swift"
git commit -m "feat(watch): add WatchAudioRecorder with metering"
```

---

### Task 3: Watch Recording Screen

**Files:**
- Create: `Reveri Watch App/Views/WatchRecordingView.swift`
- Create: `Reveri Watch App/Views/WatchWaveformView.swift`

**Context:**
- 2-screen flow: Recording → Emotion Picker
- Record button: large circle, tap to start/stop
- Waveform: simplified version — just live bars during recording
- Timer showing recording duration
- After stop → navigate to EmotionPicker

**Step 1: Create simplified waveform for Watch**

```swift
import SwiftUI

struct WatchWaveformView: View {
    let level: Float  // 0...1
    let isRecording: Bool

    @State private var bars: [Float] = Array(repeating: 0, count: 12)

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<12, id: \.self) { i in
                Capsule()
                    .fill(Color.white.opacity(0.8))
                    .frame(width: 3, height: CGFloat(bars[i]) * 30 + 3)
            }
        }
        .frame(height: 36)
        .onChange(of: level) { _, newLevel in
            guard isRecording else { return }
            bars.removeFirst()
            bars.append(newLevel)
        }
    }
}
```

**Step 2: Create WatchRecordingView**

```swift
import SwiftUI
import SwiftData

struct WatchRecordingView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var recorder = WatchAudioRecorder()
    @State private var showEmotionPicker = false
    @State private var savedDream: Dream?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Spacer()

                if recorder.isRecording {
                    WatchWaveformView(level: recorder.currentLevel, isRecording: true)

                    Text(formatDuration(recorder.duration))
                        .font(.system(.title3, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.7))
                }

                Button {
                    if recorder.isRecording {
                        stopAndSave()
                    } else {
                        startRecording()
                    }
                } label: {
                    Circle()
                        .fill(recorder.isRecording ? .red : .white)
                        .frame(width: 64, height: 64)
                        .overlay {
                            if recorder.isRecording {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(.white)
                                    .frame(width: 22, height: 22)
                            } else {
                                Circle()
                                    .fill(.red)
                                    .frame(width: 54, height: 54)
                            }
                        }
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .navigationDestination(isPresented: $showEmotionPicker) {
                if let dream = savedDream {
                    WatchEmotionPickerView(dream: dream)
                }
            }
        }
    }

    private func startRecording() {
        try? recorder.startRecording()
    }

    private func stopAndSave() {
        recorder.stopRecording()

        guard let audioPath = recorder.audioFilePath else { return }

        let dream = Dream(text: "", createdAt: Date())
        dream.audioFilePath = audioPath
        modelContext.insert(dream)
        try? modelContext.save()

        savedDream = dream
        showEmotionPicker = true
    }

    private func formatDuration(_ t: TimeInterval) -> String {
        let m = Int(t) / 60
        let s = Int(t) % 60
        return String(format: "%d:%02d", m, s)
    }
}
```

**Step 3: Update ReveriApp.swift to use WatchRecordingView**

Already done in Task 1 Step 4 — it points to `WatchRecordingView()`.

**Step 4: Build**

```bash
xcodebuild -scheme "Reveri Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)' build
```

**Step 5: Commit**

```bash
git add "Reveri Watch App/Views/"
git commit -m "feat(watch): add recording screen with waveform"
```

---

### Task 4: Watch Emotion Picker Screen

**Files:**
- Create: `Reveri Watch App/Views/WatchEmotionPickerView.swift`

**Context:**
- Shows after recording stops
- Grid of 7 emotions (emoji + name)
- Tap → assign emotion to Dream, dismiss back to recording
- "Skip" button to save without emotion
- Watch screen is small — use List or compact grid

**Step 1: Create WatchEmotionPickerView**

```swift
import SwiftUI
import SwiftData

struct WatchEmotionPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let dream: Dream

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Text("Как ощущался сон?")
                    .font(.headline)

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    ForEach(DreamEmotion.allCases) { emotion in
                        Button {
                            selectEmotion(emotion)
                        } label: {
                            VStack(spacing: 4) {
                                Text(emotion.emoji)
                                    .font(.title2)
                                Text(emotion.displayName)
                                    .font(.caption2)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button("Пропустить") {
                    dismiss()
                }
                .foregroundStyle(.white.opacity(0.5))
                .padding(.top, 4)
            }
        }
    }

    private func selectEmotion(_ emotion: DreamEmotion) {
        dream.emotionValues = [emotion.rawValue]
        dismiss()
    }
}
```

**Step 2: Build**

```bash
xcodebuild -scheme "Reveri Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)' build
```

**Step 3: Commit**

```bash
git add "Reveri Watch App/Views/WatchEmotionPickerView.swift"
git commit -m "feat(watch): add emotion picker screen"
```

---

### Task 5: WatchConnectivity — Watch Side (Send Audio)

**Files:**
- Create: `Reveri Watch App/Services/WatchSessionManager.swift`

**Context:**
- Watch sends audio file to iPhone after recording
- Use `WCSession.default.transferFile()` — reliable background transfer
- Also send Dream's `persistentModelID` or `id` as metadata so iPhone knows which Dream to update
- Watch initiates session activation on app launch

**Step 1: Create WatchSessionManager**

```swift
import WatchConnectivity
import Observation

@Observable
final class WatchSessionManager: NSObject, WCSessionDelegate {
    var isReachable = false

    override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    func transferAudioFile(url: URL, dreamId: UUID) {
        guard WCSession.default.activationState == .activated else { return }

        WCSession.default.transferFile(
            url,
            metadata: ["dreamId": dreamId.uuidString]
        )
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        if let error {
            print("Watch WCSession activation error: \(error)")
        }
    }
}
```

**Step 2: Integrate into WatchRecordingView**

In `WatchRecordingView.swift`, add:
- `@State private var sessionManager = WatchSessionManager()`
- After saving Dream, call `sessionManager.transferAudioFile(url:dreamId:)`

Update `stopAndSave()`:
```swift
private func stopAndSave() {
    recorder.stopRecording()
    guard let audioPath = recorder.audioFilePath,
          let audioURL = recorder.audioFileURL else { return }

    let dream = Dream(text: "", createdAt: Date())
    dream.audioFilePath = audioPath
    modelContext.insert(dream)
    try? modelContext.save()

    // Transfer audio to iPhone
    sessionManager.transferAudioFile(url: audioURL, dreamId: dream.id)

    savedDream = dream
    showEmotionPicker = true
}
```

**Step 3: Build and commit**

```bash
xcodebuild -scheme "Reveri Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)' build
git add "Reveri Watch App/Services/WatchSessionManager.swift" "Reveri Watch App/Views/WatchRecordingView.swift"
git commit -m "feat(watch): add WatchConnectivity to transfer audio to iPhone"
```

---

### Task 6: WatchConnectivity — iPhone Side (Receive Audio)

**Files:**
- Create: `ReveriAI/Services/PhoneSessionManager.swift`
- Modify: `ReveriAI/ReveriAIApp.swift` (activate WCSession on launch)

**Context:**
- iPhone receives audio file from Watch via WCSession delegate
- Finds Dream by UUID (synced via CloudKit), runs speech recognition, updates Dream.text
- Must handle: file received when app is in background (transferFile is reliable)
- SpeechRecognitionService already exists — reuse for transcription

**Step 1: Create PhoneSessionManager**

```swift
import WatchConnectivity
import SwiftData
import Observation

@Observable
final class PhoneSessionManager: NSObject, WCSessionDelegate {
    private var modelContainer: ModelContainer?

    func configure(with container: ModelContainer) {
        self.modelContainer = container
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {}

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        guard let metadata = file.metadata,
              let dreamIdString = metadata["dreamId"] as? String,
              let dreamId = UUID(uuidString: dreamIdString) else { return }

        // Copy file to app's recordings directory
        let fileName = "watch_\(Int(Date().timeIntervalSince1970)).m4a"
        let destDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("recordings")
        let destURL = destDir.appendingPathComponent(fileName)

        do {
            try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
            try FileManager.default.moveItem(at: file.fileURL, to: destURL)
        } catch {
            print("Failed to save Watch audio: \(error)")
            return
        }

        // Update Dream on main thread
        Task { @MainActor in
            guard let container = self.modelContainer else { return }
            let context = container.mainContext
            let predicate = #Predicate<Dream> { $0.id == dreamId }
            let descriptor = FetchDescriptor(predicate: predicate)

            if let dream = try? context.fetch(descriptor).first {
                dream.audioFilePath = "recordings/\(fileName)"
                try? context.save()
                // TODO: Run speech recognition on the audio file
            }
        }
    }
}
```

**Step 2: Activate in ReveriAIApp.swift**

Add `PhoneSessionManager` as a property and configure it after ModelContainer creation:

```swift
@State private var phoneSessionManager = PhoneSessionManager()

// After container creation:
phoneSessionManager.configure(with: container)
```

**Step 3: Build and commit**

```bash
xcodebuild -scheme ReveriAI -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
git add ReveriAI/Services/PhoneSessionManager.swift ReveriAI/ReveriAIApp.swift
git commit -m "feat(watch): add iPhone-side WatchConnectivity to receive audio"
```

---

### Task 7: Watch Complication

**Files:**
- Create: `Reveri Watch App/Complication/ReveriComplication.swift`
- Modify: `Reveri Watch App/ReveriApp.swift` (add complication support)

**Context:**
- Simple Graphic Circular complication with app icon
- Tap opens app → goes to RecordingView
- Uses WidgetKit (CLKComplicationDataSource is deprecated)

**Step 1: Create complication**

```swift
import WidgetKit
import SwiftUI

struct ReveriComplication: Widget {
    let kind = "ReveriComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ReveriTimelineProvider()) { entry in
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "mic.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
            }
        }
        .configurationDisplayName("Reveri")
        .description("Быстрая запись сна")
        .supportedFamilies([.accessoryCircular, .accessoryCorner])
    }
}

struct ReveriTimelineEntry: TimelineEntry {
    let date: Date
}

struct ReveriTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> ReveriTimelineEntry {
        ReveriTimelineEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (ReveriTimelineEntry) -> Void) {
        completion(ReveriTimelineEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ReveriTimelineEntry>) -> Void) {
        let entry = ReveriTimelineEntry(date: .now)
        completion(Timeline(entries: [entry], policy: .never))
    }
}
```

**Step 2: Register in ReveriApp.swift extras**

The complication widget is automatically discovered by watchOS via `@main Widget` or by adding it to a `WidgetBundle` if needed. For a single complication, the `Widget` protocol alone suffices — just ensure the file is in the Watch target.

**Step 3: Build and commit**

```bash
xcodebuild -scheme "Reveri Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)' build
git add "Reveri Watch App/Complication/"
git commit -m "feat(watch): add complication for quick launch"
```

---

### Task 8: Link Watch App to iPhone App (Bundle ID)

**Context:**
- Watch app bundle ID must be child of iPhone app: `com.reveri.ReveriAI.watchkitapp`
- Since Xcode dialog didn't link them, we fix it manually

**Step 1: In Xcode**

1. Select **Reveri Watch App** target → General
2. Set Bundle Identifier to: `com.reveri.ReveriAI.watchkitapp`
3. Under **General → Deployment Info**, confirm watchOS 11.0+ minimum

**Step 2: Verify the companion app association**

In `Reveri Watch App` target → Info tab, add if not present:
- `WKCompanionAppBundleIdentifier` = `com.reveri.ReveriAI`

**Step 3: In iPhone target**

ReveriAI target → Info tab, ensure no additional config needed (modern watchOS apps auto-pair by bundle ID hierarchy).

**Step 4: Clean build both targets**

```bash
xcodebuild clean -scheme ReveriAI
xcodebuild -scheme ReveriAI -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
xcodebuild -scheme "Reveri Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)' build
```

**Step 5: Commit**

```bash
git add -A
git commit -m "chore(watch): link Watch app bundle ID to iPhone app"
```

---

## Task Order & Dependencies

```
Task 1 (SwiftData + CloudKit) ← foundation, do first
Task 8 (Bundle ID linking) ← can do in parallel with Task 1
Task 2 (Audio Recorder) ← needs Task 1
Task 3 (Recording Screen) ← needs Task 2
Task 4 (Emotion Picker) ← needs Task 3
Task 5 (WC Watch side) ← needs Task 2, 3
Task 6 (WC iPhone side) ← needs Task 1
Task 7 (Complication) ← independent, any time after Task 3
```

## Testing Checklist

- [ ] Watch app builds and launches on simulator
- [ ] Record button starts/stops audio recording
- [ ] Waveform animates during recording
- [ ] Timer counts up during recording
- [ ] After stop → emotion picker appears
- [ ] Selecting emotion saves to Dream and dismisses
- [ ] Skip button works
- [ ] Dream appears in iPhone Journal (CloudKit sync)
- [ ] Audio file transfers to iPhone (WatchConnectivity)
- [ ] Complication appears in watch face editor
- [ ] Tapping complication opens app
