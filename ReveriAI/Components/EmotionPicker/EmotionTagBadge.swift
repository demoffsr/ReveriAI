import SwiftUI

struct EmotionTagBadge: View {
    enum Style {
        case card
        case detail
    }

    let emotion: DreamEmotion
    var iconSize: CGFloat = 18
    var fontSize: CGFloat = 12
    var style: Style = .card

    private var gradientEdge: Color {
        switch style {
        case .card: Color(red: 0.98, green: 0.98, blue: 0.98)
        case .detail: Color(red: 0.95, green: 0.95, blue: 0.95)
        }
    }

    private var gradientCenter: Color {
        switch style {
        case .card: .white
        case .detail: Color(red: 0.99, green: 0.99, blue: 0.99)
        }
    }

    private var strokeColor: Color {
        switch style {
        case .card: Color(red: 0.95, green: 0.95, blue: 0.95)
        case .detail: .white
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(emotion.iconName)
                .resizable()
                .frame(width: iconSize, height: iconSize)
            Text(emotion.displayName)
                .font(.system(size: fontSize, weight: .medium))
                .foregroundStyle(emotion.color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            LinearGradient(
                stops: [
                    Gradient.Stop(color: gradientEdge, location: 0.00),
                    Gradient.Stop(color: gradientCenter, location: 0.50),
                    Gradient.Stop(color: gradientEdge, location: 1.00),
                ],
                startPoint: UnitPoint(x: 0, y: 0.19),
                endPoint: UnitPoint(x: 1, y: 0.81)
            )
        )
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .inset(by: 0.25)
                .stroke(strokeColor, lineWidth: 0.5)
        )
    }
}
