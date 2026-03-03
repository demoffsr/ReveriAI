import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            navBar
            ScrollView {
                Text(privacyText)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .padding(20)
                    .padding(.bottom, 40)
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
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
            Text(String(localized: "profile.privacyPolicy", defaultValue: "Privacy Policy"))
                .font(.headline)
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var privacyText: String {
        String(localized: "legal.privacyPolicyText", defaultValue: """
        Last updated: February 2026

        ReveriAI ("we", "our", "the app") is a dream journal application. Your privacy is important to us.

        1. Data Collection

        We collect and store dream entries (text, audio recordings, emotions) that you create within the app. This data is stored locally on your device using Apple's SwiftData framework.

        When you use AI-powered features (dream title generation, dream interpretation, dream image generation), the text of your dream is sent to our cloud service for processing. No audio recordings are transmitted.

        2. Data Storage

        Your dream journal data is stored locally on your device. AI-generated content (titles, interpretations, images) may be cached locally for performance.

        3. Third-Party Services

        We use the following third-party services:
        • OpenAI API — for generating dream titles, interpretations, and images
        • Supabase — as a backend relay for AI requests
        • Apple Speech Recognition — for voice-to-text transcription (processed on-device when possible)

        4. Permissions

        The app may request the following permissions:
        • Microphone — for recording dream audio entries
        • Speech Recognition — for transcribing voice recordings
        • Notifications — for dream reminders
        • Photo Library — for selecting a profile avatar

        5. Data Sharing

        We do not sell, trade, or share your personal data with third parties for marketing purposes. Dream text is shared with AI services solely for the purpose of generating content you request.

        6. Data Deletion

        You can delete individual dreams at any time from the journal. Deleting the app removes all locally stored data. Cached AI-generated images can be cleared from the app settings.

        7. Children's Privacy

        The app is not directed at children under 13. We do not knowingly collect personal information from children.

        8. Changes

        We may update this policy from time to time. Continued use of the app constitutes acceptance of the updated policy.

        9. Contact

        For questions about this privacy policy, contact us at demidovdmitry07@gmail.com.
        """)
    }
}
