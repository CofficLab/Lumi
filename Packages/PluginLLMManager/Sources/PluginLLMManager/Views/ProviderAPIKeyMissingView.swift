import LumiUI
import ProviderLLMManager
import KitLLM
import ProviderMessage
import SwiftUI

/// API Key 缺失消息卡片：内联输入 Key → 保存 → 重发引导。
///
/// 复刻老版 `ProviderAPIKeyMissingView`（LLMProviderManagerPlugin）的交互，
/// 供应商类型换成新体系 `SuperLLMProvider`（`setApiKey/getApiKey/hasApiKey`）。
struct ProviderAPIKeyMissingView: View {
    @LumiTheme private var theme

    let message: Message
    let manager: any LLMManaging

    @State private var apiKey: String = ""
    @State private var isAPIKeyVisible = false
    @State private var saveError: String?
    @State private var didSaveAPIKey = false
    /// 内联 "Details" 展开状态。
    @State private var isDetailsExpanded = false

    private var provider: (any SuperLLMProvider)? {
        // 错误消息通常不带 providerID(AgentLoop.appendError 未填),用当前选中兜底,
        // 否则 provider == nil 会把输入框 disabled,表现为"点不进去"。
        let providerID = message.providerID ?? manager.selectedProviderID
        guard let providerID else { return nil }
        return manager.provider(id: providerID)
    }

    private var providerName: String {
        provider.map { $0.providerInfo.displayName }
            ?? message.rawErrorDetail?.replacingOccurrences(of: "\(LLMProviderAPIKeyMessage.rawErrorPrefix) ", with: "")
            ?? "LLM Provider"
    }

    private var providerWebsiteURL: URL? {
        provider?.providerInfo.websiteURL
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "key.fill")
                    .font(.appCallout)
                    .foregroundStyle(theme.primary)

                Text(String(format: "%@ API Key required", providerName))
                    .font(.appCallout)
                    .fontWeight(.semibold)
                    .foregroundStyle(theme.textPrimary)

                Spacer(minLength: 8)
            }

            Text(LumiPluginLocalization.string("Enter an API Key here, then resend your message.", bundle: .module))
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
                // 用原生 AppKit 输入框包装：macOS 消息列表是 SwiftUI List(NSTableView)，
                // SwiftUI TextField 在行内点击拿不到焦点（光标不闪）。原生 NSTextField
                // 通过 AppKit first responder 机制点击即可聚焦。
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

                    if didSaveAPIKey {
                        Label(LumiPluginLocalization.string("Saved", bundle: .module), systemImage: "checkmark.circle.fill")
                            .font(.appCaption)
                            .foregroundStyle(theme.success)
                    }
                }
            }

            if let saveError {
                Text(saveError)
                    .font(.appCaption)
                    .foregroundStyle(theme.error)
                    .textSelection(.enabled)
            }

            if provider == nil {
                Text(LumiPluginLocalization.string("Provider is not registered yet. Open Settings to configure this key.", bundle: .module))
                    .font(.appCaption)
                    .foregroundStyle(theme.textSecondary)
            }

            DisclosureGroup(isExpanded: $isDetailsExpanded) {
                if let raw = message.rawErrorDetail, !raw.isEmpty {
                    Text(raw)
                        .font(.appCaption)
                        .foregroundStyle(theme.textSecondary)
                        .textSelection(.enabled)
                        .padding(.top, 4)
                }
            } label: {
                Text(LumiPluginLocalization.string("Details", bundle: .module))
                    .font(.appCaption)
                    .foregroundStyle(theme.textSecondary)
            }
        }
        .padding(12)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(theme.divider, lineWidth: 1)
        }
        .onAppear {
            apiKey = provider?.getApiKey() ?? ""
        }
    }

    private func saveAPIKey() {
        guard let provider else { return }
        provider.setApiKey(apiKey)
        apiKey = provider.getApiKey()
        saveError = nil
        didSaveAPIKey = true
    }
}
