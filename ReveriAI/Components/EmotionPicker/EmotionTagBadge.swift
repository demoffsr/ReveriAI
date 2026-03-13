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

    @Environment(\.theme) private var theme

    private var gradientEdge: Color {
        if theme.isDayTime {
            switch style {
            case .card: return Color(red: 0.98, green: 0.98, blue: 0.98)
            case .detail: return Color(red: 0.95, green: 0.95, blue: 0.95)
            }
        } else {
            switch style {
            case .card: return Color(red: 0.17, green: 0.17, blue: 0.17)
            case .detail: return Color(red: 0.20, green: 0.20, blue: 0.20)
            }
        }
    }

    private var gradientCenter: Color {
        if theme.isDayTime {
            switch style {
            case .card: return .white
            case .detail: return Color(red: 0.99, green: 0.99, blue: 0.99)
            }
        } else {
            switch style {
            case .card: return Color(red: 0.20, green: 0.20, blue: 0.20)
            case .detail: return Color(red: 0.22, green: 0.22, blue: 0.22)
            }
        }
    }

    private var strokeColor: Color {
        if theme.isDayTime {
            switch style {
            case .card: return Color(red: 0.95, green: 0.95, blue: 0.95)
            case .detail: return .white
            }
        } else {
            switch style {
            case .card: return Color(red: 0.25, green: 0.25, blue: 0.25)
            case .detail: return Color(red: 0.30, green: 0.30, blue: 0.30)
            }
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
