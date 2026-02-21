import SwiftUI

struct HowDidItFeelCard: View {
    let onTap: () -> Void
    let onDismiss: () -> Void
    var showSavedState: Bool = false
    @Environment(\.theme) private var theme

    private let savedColor = Color(hex: "4CAF50")

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                if showSavedState {
                    // "Dream saved" capsule (green)
                    Text("Dream saved")
                        .font(.subheadline.weight(.medium))
                        .tracking(-0.23)
                        .foregroundStyle(savedColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(savedColor.opacity(0.1)))
                        .reveriGlass(.capsule, interactive: false)
                        .transition(.opacity)
                } else {
                    // "How did it feel?" capsule
                    Button(action: onTap) {
                        Text("How did it feel?")
                            .font(.subheadline.weight(.medium))
                            .tracking(-0.23)
                            .foregroundStyle(Color.black.opacity(0.6))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .reveriGlass(.capsule)
                    .transition(.opacity)

                    // Close button
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.black.opacity(0.6))
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                    .reveriGlass(.circle)
                    .transition(.opacity)
                }
            }
        }

    }
}
