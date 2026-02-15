import Foundation
import SwiftData

@Model
final class DreamFolder {
    var id: UUID
    var name: String
    var createdAt: Date
    @Relationship(inverse: \Dream.folder) var dreams: [Dream]

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = .now
        self.dreams = []
    }
}
