import Foundation
import Functions
import Supabase
import os

/// Lightweight analytics service that tracks user events to the `app_events` table
/// via the `track-event` Supabase Edge Function.
///
/// Usage:
/// ```swift
/// AnalyticsService.track(.dreamRecorded, metadata: ["mode": "text"])
/// ```
///
/// Events are queued in-memory and flushed in batches every 10 seconds
/// or when the batch reaches 10 events. On app background, the queue
/// is flushed immediately.
enum AnalyticsService {
    // MARK: - Event Types

    enum EventType: String {
        // Session
        case sessionStart = "session_start"
        case appForeground = "app_foreground"
        case appBackground = "app_background"

        // Recording
        case recordStarted = "record_started"
        case recordStopped = "record_stopped"
        case recordPaused = "record_paused"
        case recordResumed = "record_resumed"
        case recordDeleted = "record_deleted"
        case modeSwitched = "mode_switched"             // voice↔text toggle

        // Dream saving
        case dreamRecorded = "dream_recorded"           // text dream
        case reviewSavedAudio = "review_saved_audio"    // audio dream

        // Emotions
        case emotionsSelected = "emotions_selected"
        case emotionFilterChanged = "emotion_filter_changed"

        // AI features
        case aiTitleStarted = "ai_title_started"
        case aiTitleCompleted = "ai_title_completed"
        case aiTitleFailed = "ai_title_failed"
        case aiImageStarted = "ai_image_started"
        case aiImageCompleted = "ai_image_completed"
        case aiImageFailed = "ai_image_failed"
        case aiInterpretationStarted = "ai_interpretation_started"
        case aiInterpretationCompleted = "ai_interpretation_completed"
        case aiInterpretationFailed = "ai_interpretation_failed"
        case aiTranscriptionStarted = "ai_transcription_started"
        case aiTranscriptionCompleted = "ai_transcription_completed"
        case aiTranscriptionFailed = "ai_transcription_failed"
        case aiTitleRegenerated = "ai_title_regenerated"

        // Navigation
        case tabSwitched = "tab_switched"
        case deepLinkRecord = "deep_link_record"
        case deepLinkWrite = "deep_link_write"
        case dreamDetailOpened = "dream_detail_opened"
        case dreamDetailTabSwitched = "dream_detail_tab_switched"
        case profileOpened = "profile_opened"
        case searchOpened = "search_opened"
        case searchResultTapped = "search_result_tapped"

        // Reminder
        case reminderStarted = "reminder_started"
        case reminderEnded = "reminder_ended"

        // Journal actions
        case folderCreated = "folder_created"
        case folderDeleted = "folder_deleted"
        case folderOpened = "folder_opened"
        case dreamMovedToFolder = "dream_moved_to_folder"
        case dreamDeleted = "dream_deleted"
        case dreamShared = "dream_shared"
        case dreamEdited = "dream_edited"
        case dreamEmotionsChanged = "dream_emotions_changed"
        case timeRangeChanged = "time_range_changed"
        case journalTabSwitched = "journal_tab_switched"  // dreams↔folders

        // Playback
        case audioPlaybackStarted = "audio_playback_started"
        case audioPlaybackSkip = "audio_playback_skip"

        // Profile settings
        case languageChanged = "language_changed"
        case reminderToggled = "reminder_toggled"
        case reminderTimeChanged = "reminder_time_changed"
        case themeChanged = "theme_changed"
        case cacheCleared = "cache_cleared"
        case rateAppTapped = "rate_app_tapped"
        case contactUsTapped = "contact_us_tapped"
    }

    // MARK: - Internal Types

    private struct EventPayload: Encodable {
        let event_type: String
        let session_id: String
        let user_id: String
        let metadata: [String: AnyCodable]?
        let device: String?
        let app_version: String
        let os_version: String
        let locale: String
        let created_at: String
    }

    private struct BatchBody: Encodable {
        let events: [EventPayload]
    }

    private struct TrackResponse: Decodable {
        let ok: Bool?
        let count: Int?
    }

    private struct RegisterBody: Encodable {
        let device: String
        let os_version: String
        let app_version: String
        let auth_user_id: String?
    }

    private struct RegisterResponse: Decodable {
        let user_id: String
        let token: String
    }

    // MARK: - State

    private static let logger = Logger(subsystem: "com.reveri", category: "Analytics")
    private static let lock = NSLock()

    // Session ID — unique per app launch
    nonisolated(unsafe) private static var _sessionId: String = UUID().uuidString
    nonisolated(unsafe) private static var _queue: [EventPayload] = []
    nonisolated(unsafe) private static var _flushTask: Task<Void, Never>?
    nonisolated(unsafe) private static var _isSetup = false
    nonisolated(unsafe) private static var _credentials: AnalyticsKeychain.Credentials?
    nonisolated(unsafe) private static var _registrationTask: Task<Bool, Never>?

    private static let batchSize = 10
    private static let flushInterval: TimeInterval = 10

    // MARK: - Device / App Info

    private static var deviceString: String {
        #if targetEnvironment(simulator)
        return "Simulator"
        #else
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { id, element in
            guard let value = element.value as? Int8, value != 0 else { return id }
            return id + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
        #endif
    }

    private static let appVersion: String = {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }()

    private static let osVersion: String = {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "iOS \(v.majorVersion).\(v.minorVersion)"
    }()

    private static let localeString: String = {
        Locale.current.identifier
    }()

    // MARK: - Public API

    /// Call once from RootView.task to start the flush timer and track session_start.
    static func setup() {
        lock.lock()
        guard !_isSetup else { lock.unlock(); return }
        _isSetup = true
        _sessionId = UUID().uuidString
        lock.unlock()

        // Load credentials from Keychain
        let creds = AnalyticsKeychain.load()
        lock.lock()
        _credentials = creds
        lock.unlock()

        startFlushTimer()
        track(.sessionStart)
        logger.info("Analytics setup — session \(_sessionId.prefix(8))")
    }

    /// Track an event with optional metadata.
    static func track(_ event: EventType, metadata: [String: Any]? = nil) {
        lock.lock()
        let userId = _credentials?.userId ?? ""
        lock.unlock()

        let payload = EventPayload(
            event_type: event.rawValue,
            session_id: sessionId,
            user_id: userId,
            metadata: metadata?.mapValues { AnyCodable($0) },
            device: deviceString,
            app_version: appVersion,
            os_version: osVersion,
            locale: localeString,
            created_at: ISO8601DateFormatter().string(from: Date())
        )

        lock.lock()
        _queue.append(payload)
        let count = _queue.count
        lock.unlock()

        if count >= batchSize {
            Task { await flush() }
        }
    }

    /// Force-flush all queued events. Call on app background.
    static func flush() async {
        // Lazy registration
        let _ = await ensureRegistered()

        lock.lock()
        let events = _queue
        _queue = []
        let creds = _credentials
        lock.unlock()

        guard !events.isEmpty else { return }

        var headers: [String: String] = [:]
        if let creds {
            headers["X-Analytics-Token"] = creds.token
        }
        if let authUserId = AuthService.currentUserId {
            headers["X-Auth-User-Id"] = authUserId
        }

        do {
            let _: TrackResponse = try await SupabaseService.client.functions.invoke(
                "track-event",
                options: .init(headers: headers, body: BatchBody(events: events))
            )
            logger.info("Flushed \(events.count) events")
        } catch {
            logger.error("Flush failed: \(error.localizedDescription) — re-queuing \(events.count) events")
            // Re-queue failed events
            lock.lock()
            _queue.insert(contentsOf: events, at: 0)
            // Cap queue to prevent memory issues
            if _queue.count > 200 {
                _queue = Array(_queue.suffix(200))
            }
            lock.unlock()
        }
    }

    // MARK: - Registration

    private static func ensureRegistered() async -> Bool {
        lock.lock()
        if _credentials != nil { lock.unlock(); return true }
        if let existing = _registrationTask { lock.unlock(); return await existing.value }
        let task = Task<Bool, Never> { await register() }
        _registrationTask = task
        lock.unlock()
        return await task.value
    }

    private static func register() async -> Bool {
        do {
            let response: RegisterResponse = try await SupabaseService.client.functions.invoke(
                "register-analytics",
                options: .init(
                    headers: ["X-Analytics-API-Key": SupabaseConfig.analyticsAPIKey],
                    body: RegisterBody(
                        device: deviceString,
                        os_version: osVersion,
                        app_version: appVersion,
                        auth_user_id: AuthService.currentUserId
                    )
                )
            )

            let creds = AnalyticsKeychain.Credentials(
                userId: response.user_id,
                token: response.token
            )
            guard AnalyticsKeychain.save(creds) else {
                logger.error("Failed to save credentials to Keychain")
                lock.lock()
                _registrationTask = nil
                lock.unlock()
                return false
            }

            lock.lock()
            _credentials = creds
            _registrationTask = nil
            lock.unlock()

            // Migrate: delete old UserDefaults ONLY after Keychain save
            UserDefaults.standard.removeObject(forKey: "analyticsUserId")

            logger.info("Analytics registered — user \(response.user_id.prefix(8))")
            return true
        } catch {
            lock.lock()
            _registrationTask = nil
            lock.unlock()
            if let functionsError = error as? FunctionsError,
               case let .httpError(code, data) = functionsError {
                let body = String(data: data, encoding: .utf8) ?? "empty"
                logger.error("Registration failed: HTTP \(code) — \(body)")
            } else {
                logger.error("Registration failed: \(error.localizedDescription)")
            }
            return false
        }
    }

    // MARK: - Private

    private static var sessionId: String {
        lock.lock()
        defer { lock.unlock() }
        return _sessionId
    }

    private static func startFlushTimer() {
        lock.lock()
        _flushTask?.cancel()
        lock.unlock()

        let task = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(flushInterval))
                guard !Task.isCancelled else { break }
                await flush()
            }
        }

        lock.lock()
        _flushTask = task
        lock.unlock()
    }
}

// MARK: - AnyCodable (lightweight wrapper for JSON encoding arbitrary values)

struct AnyCodable: Encodable {
    private let value: Any

    init(_ value: Any) {
        self.value = value
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let v as String:
            try container.encode(v)
        case let v as Int:
            try container.encode(v)
        case let v as Double:
            try container.encode(v)
        case let v as Float:
            try container.encode(v)
        case let v as Bool:
            try container.encode(v)
        case let v as [String]:
            try container.encode(v)
        case let v as [String: String]:
            try container.encode(v)
        case let v as [Any]:
            let wrapped = v.map { AnyCodable($0) }
            try container.encode(wrapped)
        case let v as [String: Any]:
            let wrapped = v.mapValues { AnyCodable($0) }
            try container.encode(wrapped)
        default:
            try container.encode(String(describing: value))
        }
    }
}
