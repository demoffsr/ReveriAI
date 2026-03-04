import SwiftUI

enum DetailTabBarMode {
    case generateImage
    case generateImageAgain
    case interpretDream
    case none
}

@Observable
class DetailDreamState {
    var isActive = false
    var hasInterpretation = false
    var isGeneratingInterpretation = false
    var interpretationError: String?
    var tabBarMode: DetailTabBarMode = .none
    var interpretTrigger = false
    var showRateLimitAlert = false
}
