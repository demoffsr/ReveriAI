import SwiftUI

struct TermsOfUseView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            navBar
            ScrollView {
                Text(termsText)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .padding(20)
                    .padding(.bottom, 40)
            }
        }
        .background((theme.isDayTime ? Color(.systemGroupedBackground) : .darkBackground).ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .enableSwipeBack()
    }

    private var navBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
                    .reveriGlass(.circle)
            }
            Spacer()
            Text(String(localized: "profile.termsOfUse", defaultValue: "Terms of Use"))
                .font(.headline)
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var termsText: String {
        String(localized: "legal.termsOfUseText", defaultValue: """
        Last updated: February 2026

        By using ReveriAI ("the app"), you agree to these Terms of Use.

        1. Acceptance

        By downloading, installing, or using the app, you agree to be bound by these terms. If you do not agree, do not use the app.

        2. Description of Service

        ReveriAI is a personal dream journal application that allows you to record, organize, and analyze your dreams using text, voice, and AI-powered features.

        3. User Content

        You retain ownership of all dream entries and content you create in the app. By using AI features, you grant us a limited license to process your dream text through our AI services for the sole purpose of generating requested content (titles, interpretations, images).

        4. AI-Generated Content

        AI-generated titles, interpretations, and images are provided for entertainment and personal reflection purposes only. They should not be considered medical, psychological, or professional advice.

        5. Acceptable Use

        You agree not to:
        • Use the app for any unlawful purpose
        • Attempt to reverse-engineer the app or its AI services
        • Abuse or overload the AI generation features

        6. Availability

        We strive to keep the app functional but do not guarantee uninterrupted availability. AI features require an internet connection and may be temporarily unavailable.

        7. Limitation of Liability

        The app is provided "as is" without warranties. We are not liable for any loss of data, damages, or issues arising from use of the app or its AI-generated content.

        8. Modifications

        We reserve the right to modify these terms at any time. Continued use after changes constitutes acceptance.

        9. Termination

        We may terminate or restrict access to AI features at our discretion. You may stop using the app at any time.

        10. Contact

        For questions about these terms, contact us at demidovdmitry07@gmail.com.
        """)
    }
}
