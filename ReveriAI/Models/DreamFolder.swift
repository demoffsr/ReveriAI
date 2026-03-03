import Foundation
import SwiftData

@Model
final class DreamFolder {
    /// Set by AuthService at app launch. Auto-tags new records with owner.
    nonisolated(unsafe) static var defaultUserId: String?

    var id: UUID
    var userId: String?
    var name: String
    var createdAt: Date
    @Relationship(inverse: \Dream.folder) var dreams: [Dream]

    init(name: String) {
        self.id = UUID()
        self.userId = Self.defaultUserId
        self.name = name
        self.createdAt = .now
        self.dreams = []
    }
}
