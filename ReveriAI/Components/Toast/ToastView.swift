import SwiftUI

enum ToastStyle {
    case success, error

    var color: Color {
        switch self {
        case .success: .green
        case .error: .red
        }
    }
}

struct ToastView: View {
    let message: String
    let icon: String
    let style: ToastStyle

    init(_ message: String, icon: String = "checkmark.circle.fill", style: ToastStyle = .success) {
        self.message = message
        self.icon = icon
        self.style = style
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(style.color)
            Text(message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.1), radius: 10, y: 4)
    }
}
