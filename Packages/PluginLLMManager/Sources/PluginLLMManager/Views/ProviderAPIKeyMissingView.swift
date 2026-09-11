import LumiUI
import ProviderMessage
import SwiftUI

/// API Key 缺失消息卡片：内联输入 Key → 保存 → 重发引导。
///
/// 复刻老版 `ProviderAPIKeyMissingView`（LLMProviderManagerPlugin）的交互，
/// 供应商解析与 Key 读写由 `ProviderAPIKeyViewModel` 提供，View 不持有
/// `LLMManaging` 或任何 Provider。
struct ProviderAPIKeyMissingView: View {
    @LumiTheme private var theme

    let message: Message
    @ObservedObject private var viewModel: ProviderAPIKeyViewModel

    /// 内联 "Details" 展开状态。
    @State private var isDetailsExpanded = false
    /// API Key 明文/密文切换（纯 UI 状态）。
    @State private var isAPIKeyVisible = false

    init(message: Message, viewModel: ProviderAPIKeyViewModel) {
        self.message = message
        self.viewModel = viewModel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "key.fill")
                    .font(.appCallout)
                    .foregroundStyle(theme.primary)

                Text(
                    viewModel.keyIsReadable
                        ? String(format: "%@ API Key available", viewModel.providerName)
                        : String(format: "%@ API Key required", viewModel.providerName)
                )
                    .font(.appCallout)
                    .fontWeight(.semibold)
                    .foregroundStyle(theme.textPrimary)

                Spacer(minLength: 8)
            }

            Text(
                LumiPluginLocalization.string(
                    viewModel.keyIsReadable
                        ? "The API Key is readable again. Resend the message to continue."
                        : "Enter an API Key here, then resend your message.",
                    bundle: .module
                )
            )
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
                // 用原生 AppKit 输入框包装：macOS 消息列表是 SwiftUI List(NSTableView)，
                // SwiftUI TextField 在行内点击拿不到焦点（光标不闪）。原生 NSTextField
                // 通过 AppKit first responder 机制点击即可聚焦。
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

            if viewModel.providerAvailable, !viewModel.keyIsReadable {
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

                    if viewModel.didSaveAPIKey {
                        Label(LumiPluginLocalization.string("Saved", bundle: .module), systemImage: "checkmark.circle.fill")
                            .font(.appCaption)
                            .foregroundStyle(theme.success)
                    }
                }
            }

            if let saveError = viewModel.saveError {
                Text(saveError)
                    .font(.appCaption)
                    .foregroundStyle(theme.error)
                    .textSelection(.enabled)
            }

            if !viewModel.providerAvailable {
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
    }
}
