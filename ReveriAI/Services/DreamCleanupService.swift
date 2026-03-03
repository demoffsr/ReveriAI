import SwiftUI
import SwiftData
import os

enum DreamCleanupService {
    private static let logger = Logger(subsystem: "com.reveri.ai", category: "Cleanup")

    private static let recordingsDirectory: URL = {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("recordings")
    }()

    /// Deletes a Dream and all associated files (local image, local audio, remote image).
    static func deleteDream(_ dream: Dream, context: ModelContext, animated: Bool = true) {
        AnalyticsService.track(.dreamDeleted, metadata: [
            "had_audio": dream.audioFilePath != nil,
            "had_image": dream.imagePath != nil,
            "had_emotions": !dream.emotions.isEmpty
        ])
        let imagePath = dream.imagePath
        let audioFilePath = dream.audioFilePath

        let doDelete = {
            context.delete(dream)
            try? context.save()
        }

        if animated {
            withAnimation(.easeOut(duration: 0.3)) { doDelete() }
        } else {
            doDelete()
        }

        // Local image
        if let imagePath {
            DreamAIService.deleteLocalImage(imagePath: imagePath)
        }

        // Local audio
        if let audioFilePath {
            let audioURL = recordingsDirectory.appendingPathComponent(audioFilePath)
            try? FileManager.default.removeItem(at: audioURL)
        }

        // Remote image (fire-and-forget with retry queue)
        if let imagePath {
            DreamAIService.deleteImageFromStorage(imagePath: imagePath)
        }
    }
}
