import SwiftUI

/// Unified Liquid Glass modifier — native Apple glass with subtle white tint.
/// Usage: `.reveriGlass(.circle)` or `.reveriGlass(.capsule)`
struct ReveriGlassModifier: ViewModifier {
    enum Shape {
        case circle
        case capsule
    }

    let shape: Shape

    func body(content: Content) -> some View {
        switch shape {
        case .circle:
            content
                .glassEffect(
                    .regular.tint(.white.opacity(0.15)).interactive(),
                    in: .circle
                )
        case .capsule:
            content
                .glassEffect(
                    .regular.tint(.white.opacity(0.15)).interactive(),
                    in: .capsule
                )
        }
    }
}

extension View {
    func reveriGlass(_ shape: ReveriGlassModifier.Shape) -> some View {
        modifier(ReveriGlassModifier(shape: shape))
    }
}
