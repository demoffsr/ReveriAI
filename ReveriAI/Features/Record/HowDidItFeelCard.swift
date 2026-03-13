import SwiftUI

struct HowDidItFeelCard: View {
    let onTap: () -> Void
    let onDismiss: () -> Void
    var showSavedState: Bool = false
    @Environment(\.theme) private var theme

    private let savedColor = Color(hex: "4CAF50")

    var body: some View {
        HStack(spacing: 8) {
            if showSavedState {
                // "Dream saved" capsule (green)
                Text(String(localized: "record.dreamSaved", defaultValue: "Dream saved"))
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
                    Text(String(localized: "record.howDidItFeel", defaultValue: "How did it feel?"))
                        .font(.subheadline.weight(.medium))
                        .tracking(-0.23)
                        .foregroundStyle(theme.textPrimary.opacity(0.6))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .reveriGlass(.capsule)
                .transition(.opacity)

                // Close button
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(theme.textPrimary.opacity(0.6))
                    .frame(width: 36, height: 36)
                    .contentShape(Circle())
                    .reveriGlass(.circle, interactive: false)
                    .onTapGesture { onDismiss() }
                    .transition(.opacity)
            }
        }
    }
}
