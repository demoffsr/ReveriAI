import Foundation
import SwiftOGG

enum AudioConversionService {
    static func convertToOpus(source: URL) async throws -> URL {
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("dream_voice.ogg")
        try? FileManager.default.removeItem(at: dest)
        try OGGConverter.convertM4aFileToOpusOGG(src: source, dest: dest)
        return dest
    }
}
