import LumiKernel
import LumiUI
import SwiftUI

struct ProviderAPIKeyAccessFailedView: View {
    @LumiTheme private var theme

    let message: LumiChatMessage
    let provider: (any LumiLLMProvider)?

    private var providerName: String {
        provider.map { type(of: $0).info.displayName } ?? "LLM Provider"
    }

    private var details: String {
        let raw = message.rawErrorDetail?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return raw.isEmpty ? "macOS Keychain returned an unknown read error." : raw
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "key.slash.fill")
                    .font(.appCallout)
                    .foregroundStyle(theme.warning)

                Text("\(providerName) API Key unavailable")
                    .font(.appCallout)
                    .fontWeight(.semibold)
                    .foregroundStyle(theme.textPrimary)

                Spacer(minLength: 8)
            }

            Text("Lumi could not read the saved API Key from macOS Keychain. The key was not treated as missing.")
                .font(.appCaption)
                .foregroundStyle(theme.textSecondary)

            Text(details)
                .font(.appCaption)
                .foregroundStyle(theme.textSecondary)
                .textSelection(.enabled)
        }
        .padding(12)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(theme.divider, lineWidth: 1)
        }
    }
}
