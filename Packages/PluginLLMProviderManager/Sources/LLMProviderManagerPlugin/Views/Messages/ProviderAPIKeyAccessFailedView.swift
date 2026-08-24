import KernelLumi
import LumiUI
import SwiftUI

struct ProviderAPIKeyAccessFailedView: View {
    @LumiTheme private var theme

    let message: LumiChatMessage
    let provider: (any LumiLLMProvider)?

    @State private var apiKey: String = ""
    @State private var isAPIKeyVisible = false
    @State private var currentDiagnostic: LumiLLMProviderAPIKeyDiagnostic?
    @State private var isChecking = false
    @State private var saveError: String?
    @State private var didSaveAPIKey = false

    private var providerName: String {
        provider.map { type(of: $0).info.displayName } ?? "LLM Provider"
    }

    private var providerWebsiteURL: URL? {
        provider.map { type(of: $0).info.websiteURL }
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

                Text(String(
                    format: LumiPluginLocalization.string("%@ API Key unavailable", bundle: .module),
                    providerName
                ))
                    .font(.appCallout)
                    .fontWeight(.semibold)
                    .foregroundStyle(theme.textPrimary)

                Spacer(minLength: 8)
            }

            Text(LumiPluginLocalization.string("Lumi could not read the saved API Key from macOS Keychain. The key was not treated as missing.", bundle: .module))
                .font(.appCaption)
                .foregroundStyle(theme.textSecondary)

            if let providerWebsiteURL {
                Link(destination: providerWebsiteURL) {
                    Label(LumiPluginLocalization.string("Open provider website", bundle: .module), systemImage: "arrow.up.right.square")
                        .font(.appCaption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.primary)
            }

            HStack(alignment: .center, spacing: 8) {
                AppInputField(
                    LocalizedStringKey(LumiPluginLocalization.string("Enter API Key", bundle: .module)),
                    text: Binding(
                        get: { apiKey },
                        set: { apiKey = $0 }
                    ),
                    fieldType: isAPIKeyVisible ? .plain : .secure
                )
                .disabled(provider == nil)

                AppIconButton(
                    systemImage: isAPIKeyVisible ? "eye.slash" : "eye",
                    tint: isAPIKeyVisible ? theme.textPrimary : theme.textSecondary,
                    size: .regular,
                    isActive: isAPIKeyVisible
                ) {
                    isAPIKeyVisible.toggle()
                }
                .help(isAPIKeyVisible ? LumiPluginLocalization.string("Hide API Key", bundle: .module) : LumiPluginLocalization.string("Show API Key", bundle: .module))
            }

            if provider != nil {
                HStack(spacing: 8) {
                    AppButton(
                        LumiPluginLocalization.string("Save API Key", bundle: .module),
                        systemImage: "checkmark",
                        style: .primary,
                        size: .small
                    ) {
                        saveAPIKey()
                    }
                    .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    AppButton(
                        LumiPluginLocalization.string("Recheck Keychain", bundle: .module),
                        systemImage: "arrow.clockwise",
                        size: .small
                    ) {
                        recheckKeychain()
                    }
                    .disabled(isChecking)

                    if didSaveAPIKey {
                        Label(LumiPluginLocalization.string("Saved", bundle: .module), systemImage: "checkmark.circle.fill")
                            .font(.appCaption)
                            .foregroundStyle(theme.success)
                    }

                    Spacer(minLength: 0)
                }
            }

            if let saveError {
                Text(saveError)
                    .font(.appCaption)
                    .foregroundStyle(theme.error)
                    .textSelection(.enabled)
            }

            if let currentDiagnostic {
                diagnosticStatus(currentDiagnostic)
            }

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
        .task {
            refreshAPIKey()
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

    /// 预填当前可读取的 API Key;若 Keychain 仍不可读则字段保持为空,等待用户重新输入。
    private func refreshAPIKey() {
        guard let provider else {
            apiKey = ""
            return
        }
        apiKey = provider.getApiKey()
    }

    private func saveAPIKey() {
        guard let provider else { return }
        do {
            try provider.saveAPIKey(apiKey)
            apiKey = provider.getApiKey()
            currentDiagnostic = .configured
            saveError = nil
            didSaveAPIKey = true
        } catch {
            currentDiagnostic = provider.apiKeyDiagnostic()
            saveError = error.localizedDescription
            didSaveAPIKey = false
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
