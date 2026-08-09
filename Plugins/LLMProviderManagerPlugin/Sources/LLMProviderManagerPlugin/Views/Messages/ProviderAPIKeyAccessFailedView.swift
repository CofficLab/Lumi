import LumiKernel
import LumiUI
import SwiftUI

struct ProviderAPIKeyAccessFailedView: View {
    @LumiTheme private var theme

    let message: LumiChatMessage
    let provider: (any LumiLLMProvider)?
    @State private var currentDiagnostic: LumiLLMProviderAPIKeyDiagnostic?
    @State private var isChecking = false

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

            Text(LumiPluginLocalization.string("Lumi could not read the saved API Key from macOS Keychain. The key was not treated as missing.", bundle: .module))
                .font(.appCaption)
                .foregroundStyle(theme.textSecondary)

            Text(details)
                .font(.appCaption)
                .foregroundStyle(theme.textSecondary)
                .textSelection(.enabled)

            if let currentDiagnostic {
                diagnosticStatus(currentDiagnostic)
            }

            if provider != nil {
                AppButton(
                    LumiPluginLocalization.string("Recheck Keychain", bundle: .module),
                    systemImage: "arrow.clockwise",
                    size: .small
                ) {
                    recheckKeychain()
                }
                .disabled(isChecking)
            }
        }
        .padding(12)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(theme.divider, lineWidth: 1)
        }
        .task {
            recheckKeychain()
        }
    }

    @ViewBuilder
    private func diagnosticStatus(_ diagnostic: LumiLLMProviderAPIKeyDiagnostic) -> some View {
        switch diagnostic {
        case .configured:
            Text(LumiPluginLocalization.string("The API Key is readable again. Resend the message to continue.", bundle: .module))
                .font(.appCaption)
                .foregroundStyle(theme.success)
        case .missing:
            Text(LumiPluginLocalization.string("The API Key is now confirmed as missing. Open provider settings to configure it again.", bundle: .module))
                .font(.appCaption)
                .foregroundStyle(theme.warning)
        case .inaccessible(let details):
            Text(details)
                .font(.appCaption)
                .foregroundStyle(theme.warning)
                .textSelection(.enabled)
        }
    }

    private func recheckKeychain() {
        guard let provider, !isChecking else { return }
        isChecking = true
        Task {
            let diagnostic = await Task.detached {
                provider.apiKeyDiagnostic()
            }.value
            currentDiagnostic = diagnostic
            isChecking = false
        }
    }
}
