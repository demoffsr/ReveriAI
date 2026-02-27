import Foundation
import AVFoundation

enum AudioConversionService {
    /// Re-exports source M4A with VoiceMemos metadata tag.
    /// Telegram checks `AVMetadataKey.commonKeySoftware` prefix "com.apple.VoiceMemos"
    /// to decide whether to send as voice message (with waveform) vs generic audio file.
    static func prepareForShare(source: URL) async throws -> URL {
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("dream_voice.m4a")
        try? FileManager.default.removeItem(at: dest)

        let asset = AVURLAsset(url: source)
        guard let export = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetPassthrough
        ) else {
            throw NSError(domain: "AudioConversion", code: -1)
        }

        let softwareItem = AVMutableMetadataItem()
        softwareItem.key = AVMetadataKey.commonKeySoftware as NSString
        softwareItem.keySpace = .common
        softwareItem.value = "com.apple.VoiceMemos" as NSString

        export.metadata = [softwareItem]
        export.outputURL = dest
        export.outputFileType = .m4a

        await export.export()

        if let error = export.error { throw error }
        return dest
    }
}
