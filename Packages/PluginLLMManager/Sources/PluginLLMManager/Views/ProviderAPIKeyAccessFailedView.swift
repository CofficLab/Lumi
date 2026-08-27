import LumiUI
import ProviderLLMManager
import KitLLM
import ProviderMessage
import SwiftUI

/// API Key 读取失败（Keychain 访问异常）消息卡片。
///
/// 复刻老版 `ProviderAPIKeyAccessFailedView` 的交互；新体系用
/// `hasApiKey()`/`getApiKey()` 代替旧版 Keychain 诊断。
struct ProviderAPIKeyAccessFailedView: View {
    @LumiTheme private var theme

    let message: Message
    let manager: any LLMManaging

    @State private var apiKey: String = ""
    @State private var isAPIKeyVisible = false
    @State private var keyIsReadable = false
    @State private var isChecking = false
    @State private var saveError: String?
    @State private var didSaveAPIKey = false

    private var provider: (any SuperLLMProvider)? {
        // 错误消息通常不带 providerID(AgentLoop.appendError 未填),用当前选中兜底,
        // 否则 provider == nil 会把输入框 disabled,表现为"点不进去"。
        let providerID = message.providerID ?? manager.selectedProviderID
        guard let providerID else { return nil }
        return manager.provider(id: providerID)
    }

    private var providerName: String {
        provider.map { $0.providerInfo.displayName } ?? "LLM Provider"
    }

    private var providerWebsiteURL: URL? {
        provider?.providerInfo.websiteURL
    }

    private var details: String {
        let raw = message.rawErrorDetail?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return raw.isEmpty ? "Keychain returned an unknown read error." : raw
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "key.slash.fill")
                    .font(.appCallout)
                    .foregroundStyle(theme.warning)

                Text(String(format: "%@ API Key unavailable", providerName))
                    .font(.appCallout)
                    .fontWeight(.semibold)
                    .foregroundStyle(theme.textPrimary)

                Spacer(minLength: 8)
            }

            Text(LumiPluginLocalization.string("Lumi could not read the saved API Key from the system Keychain. The key was not treated as missing.", bundle: .module))
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
                // 原生 AppKit 输入框包装：绕开 SwiftUI List(NSTableView) 行内
                // TextField 拿不到焦点的问题（点击后光标不闪）。
                AppFocusableInputField(
                    "Enter API Key",
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
                .help(isAPIKeyVisible ? "Hide API Key" : "Show API Key")
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

            if keyIsReadable {
                Text(LumiPluginLocalization.string("The API Key is readable again. Resend the message to continue.", bundle: .module))
                    .font(.appCaption)
                    .foregroundStyle(theme.success)
            } else if !isChecking {
                Text(details)
                    .font(.appCaption)
                    .foregroundStyle(theme.textSecondary)
                    .textSelection(.enabled)
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
            apiKey = provider?.getApiKey() ?? ""
            recheckKeychain()
        }
    }

    private func saveAPIKey() {
        guard let provider else { return }
        provider.setApiKey(apiKey)
        apiKey = provider.getApiKey()
        keyIsReadable = provider.hasApiKey()
        saveError = nil
        didSaveAPIKey = true
    }

    private func recheckKeychain() {
        guard let provider, !isChecking else { return }
        isChecking = true
        Task { @MainActor in
            keyIsReadable = provider.hasApiKey()
            apiKey = provider.getApiKey()
            isChecking = false
        }
    }
}
