import SwiftUI

struct TextModeView: View {
    @Environment(\.theme) private var theme
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool

    var body: some View {
        TextEditor(text: $text)
            .focused($isFocused)
            .font(.body)
            .foregroundStyle(.primary)
            .tint(theme.accent)
            .scrollContentBackground(.hidden)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .overlay(alignment: .topLeading) {
                if text.isEmpty {
                    Text(String(localized: "record.enterDream", defaultValue: "Enter your dream..."))
                        .font(.body)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 21)
                        .padding(.top, 16)
                        .allowsHitTesting(false)
                }
            }
    }
}
