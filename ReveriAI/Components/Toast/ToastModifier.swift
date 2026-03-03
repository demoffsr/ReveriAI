import SwiftUI

struct ToastModifier: ViewModifier {
    @Binding var isPresented: Bool
    let message: String
    let icon: String
    let style: ToastStyle
    let duration: TimeInterval

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if isPresented {
                ToastView(message, icon: icon, style: style)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 60)
                    .task {
                        try? await Task.sleep(for: .seconds(duration))
                        withAnimation(.easeOut(duration: 0.3)) {
                            isPresented = false
                        }
                    }
            }
        }
        .animation(.spring(duration: 0.4), value: isPresented)
    }
}

extension View {
    func toast(isPresented: Binding<Bool>, message: String, icon: String = "checkmark.circle.fill", style: ToastStyle = .success, duration: TimeInterval = 2.0) -> some View {
        modifier(ToastModifier(isPresented: isPresented, message: message, icon: icon, style: style, duration: duration))
    }
}
