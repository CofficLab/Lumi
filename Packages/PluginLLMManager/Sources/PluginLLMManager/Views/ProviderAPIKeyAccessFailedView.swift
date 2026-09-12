import LumiUI
import ProviderMessage
import SwiftUI

/// API Key 读取失败（Keychain 访问异常）消息卡片。
///
/// 复刻老版 `ProviderAPIKeyAccessFailedView` 的交互；供应商解析与 Key 读写
/// 由 `ProviderAPIKeyViewModel` 提供，View 不持有 `LLMManaging`。
struct ProviderAPIKeyAccessFailedView: View {
    @LumiTheme private var theme

    let message: Message
    @ObservedObject private var viewModel: ProviderAPIKeyViewModel

    /// API Key 明文/密文切换（纯 UI 状态）。
    @State private var isAPIKeyVisible = false

    init(message: Message, viewModel: ProviderAPIKeyViewModel) {
        self.message = message
        self.viewModel = viewModel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "key.slash.fill")
                    .font(.appCallout)
                    .foregroundStyle(theme.warning)

                Text(String(format: "%@ API Key unavailable", viewModel.providerName))
                    .font(.appCallout)
                    .fontWeight(.semibold)
                    .foregroundStyle(theme.textPrimary)

                Spacer(minLength: 8)
            }

            Text(LumiPluginLocalization.string("Lumi could not read the saved API Key from the system Keychain. The key was not treated as missing.", bundle: .module))
                .font(.appCaption)
                .foregroundStyle(theme.textSecondary)

            if let providerWebsiteURL = viewModel.providerWebsiteURL {
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
                        get: { viewModel.apiKey },
                        set: { viewModel.apiKey = $0 }
                    ),
                    fieldType: isAPIKeyVisible ? .plain : .secure
                )
                .disabled(!viewModel.providerAvailable)

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

            if viewModel.providerAvailable {
                HStack(spacing: 8) {
                    AppButton(
                        LumiPluginLocalization.string("Save API Key", bundle: .module),
                        systemImage: "checkmark",
                        style: .primary,
                        size: .small
                    ) {
                        viewModel.saveAPIKey()
                    }
                    .disabled(viewModel.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    AppButton(
                        LumiPluginLocalization.string("Recheck Keychain", bundle: .module),
                        systemImage: "arrow.clockwise",
                        size: .small
                    ) {
                        viewModel.recheckKeychain()
                    }
                    .disabled(viewModel.isChecking)

                    if viewModel.didSaveAPIKey {
                        Label(LumiPluginLocalization.string("Saved", bundle: .module), systemImage: "checkmark.circle.fill")
                            .font(.appCaption)
                            .foregroundStyle(theme.success)
                    }

                    Spacer(minLength: 0)
                }
            }

            if let saveError = viewModel.saveError {
                Text(saveError)
                    .font(.appCaption)
                    .foregroundStyle(theme.error)
                    .textSelection(.enabled)
            }

            if viewModel.keyIsReadable {
                Text(LumiPluginLocalization.string("The API Key is readable again. Resend the message to continue.", bundle: .module))
                    .font(.appCaption)
                    .foregroundStyle(theme.success)
            } else if !viewModel.isChecking {
                Text(viewModel.details)
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
            viewModel.recheckKeychain()
        }
    }
}
