import SwiftUI

/// Unified Liquid Glass modifier — native Apple glass with subtle white tint.
/// Usage: `.reveriGlass(.circle)` or `.reveriGlass(.capsule)`
/// Pass `interactive: false` for static glass (no press/drag movement).
struct ReveriGlassModifier: ViewModifier {
    enum Shape {
        case circle
        case capsule
    }

    let shape: Shape
    let interactive: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        switch (shape, interactive) {
        case (.circle, true):
            content.glassEffect(.regular.interactive(), in: .circle)
        case (.circle, false):
            content.glassEffect(.regular, in: .circle)
        case (.capsule, true):
            content.glassEffect(.regular.interactive(), in: .capsule)
        case (.capsule, false):
            content.glassEffect(.regular, in: .capsule)
        }
    }
}

extension View {
    func reveriGlass(_ shape: ReveriGlassModifier.Shape, interactive: Bool = true) -> some View {
        modifier(ReveriGlassModifier(shape: shape, interactive: interactive))
    }
}
