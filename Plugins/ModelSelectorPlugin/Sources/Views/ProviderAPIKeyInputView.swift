
import LumiCoreKit
import LumiUI
import SwiftUI

/// 供应商未配置 / 需要重配 API Key 时展示的内联配置界面。
///
/// 两种使用场景：
/// 1. **未配置 API Key**：直接展示完整输入框（`onCancel` 为 nil）。
/// 2. **已配置但检测失败**：通过 "重新配置" 按钮触发，`onCancel` 关闭表单
///    回到失败提示状态。
///
/// 直接在 Model Selector 的 `ProviderSummaryCard` 内联出现，
/// 用户填入后保存即触发对应供应商的可用性重检，
/// 无需跳转到设置页。
struct ProviderAPIKeyInputView: View {
    @LumiTheme private var theme

    let provider: LumiLLMProviderInfo
    let providerInstance: any LumiLLMProvider
    /// 保存成功后的回调（用于触发可用性重检）。
    let onSaved: () -> Void
    /// 取消编辑的回调（仅 "重配" 模式下传入）。
    var onCancel: (() -> Void)? = nil

    @State private var apiKey: String = ""
    @State private var isKeyVisible: Bool = false
    @State private var didSave: Bool = false

    @FocusState private var isFieldFocused: Bool

    private var supportsCancel: Bool { onCancel != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(theme.warning)

                Text(
                    verbatim: LumiPluginLocalization.string(
                        "API Key not configured",
                        bundle: .module
                    )
                )
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(theme.warning)
            }

            HStack(alignment: .center, spacing: 6) {
                Group {
                    if isKeyVisible {
                        TextField(
                            LumiPluginLocalization.string("Enter API Key", bundle: .module),
                            text: $apiKey
                        )
                    } else {
                        SecureField(
                            LumiPluginLocalization.string("Enter API Key", bundle: .module),
                            text: $apiKey
                        )
                    }
                }
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundColor(theme.textPrimary)
                .focused($isFieldFocused)
                .onSubmit { save() }

                visibilityToggle

                saveButton
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(theme.appListRowBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(
                        didSave ? theme.success.opacity(0.6) : theme.appSubtleBorder,
                        lineWidth: 1
                    )
            )

            HStack(spacing: 12) {
                if didSave {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(theme.success)
                        Text(
                            verbatim: LumiPluginLocalization.string("Saved", bundle: .module)
                        )
                        .font(.system(size: 10))
                        .foregroundColor(theme.success)
                    }
                }

                Spacer()

                if supportsCancel {
                    Button(action: { onCancel?() }) {
                        Text(
                            verbatim: LumiPluginLocalization.string("Cancel", bundle: .module)
                        )
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(theme.textSecondary)
                    }
                    .buttonStyle(.plain)
                }

                Link(destination: provider.websiteURL) {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 10, weight: .medium))
                        Text(
                            verbatim: LumiPluginLocalization.string(
                                "Get API Key",
                                bundle: .module
                            )
                        )
                        .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(theme.primary)
                }
                .buttonStyle(.plain)
                .help(
                    LumiPluginLocalization.string(
                        "Open provider page in browser",
                        bundle: .module
                    )
                )
            }
        }
        .padding(.top, 4)
        .onAppear(perform: loadExistingKey)
    }

    // MARK: - Components

    private var visibilityToggle: some View {
        Button {
            isKeyVisible.toggle()
        } label: {
            Image(systemName: isKeyVisible ? "eye.slash" : "eye")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(theme.textSecondary)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(
            isKeyVisible
                ? LumiPluginLocalization.string("Hide API Key", bundle: .module)
                : LumiPluginLocalization.string("Show API Key", bundle: .module)
        )
    }

    private var saveButton: some View {
        Button(action: save) {
            Text(
                verbatim: LumiPluginLocalization.string("Save", bundle: .module)
            )
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(canSave ? .white : theme.textTertiary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(canSave ? theme.primary : theme.textTertiary.opacity(0.18))
            )
        }
        .buttonStyle(.plain)
        .disabled(!canSave)
        .help(
            LumiPluginLocalization.string(
                "Save and re-check availability",
                bundle: .module
            )
        )
    }

    // MARK: - Helpers

    private var canSave: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func loadExistingKey() {
        // 拉取已保存的 key（用户可能从设置页填过，也可能是 "重配" 场景下回显当前值）。
        // 仅当非空时回填，避免空字符串覆盖真实值。
        let existing = providerInstance.getApiKey()
        if !existing.isEmpty {
            apiKey = existing
        }
    }

    private func save() {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        providerInstance.setApiKey(trimmed)
        didSave = true
        isFieldFocused = false
        onSaved()

        // 短延迟后清掉 "Saved" 提示（视图会因为状态变化而整体消失/重建）
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            didSave = false
        }
    }
}
