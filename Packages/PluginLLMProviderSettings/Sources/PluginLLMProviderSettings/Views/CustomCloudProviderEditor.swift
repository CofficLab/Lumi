import KitLLM
import LumiUI
import SwiftUI

/// 新增或编辑用户自定义云端供应商。
///
/// 表单的文本解析与配置构造委托给 `CustomCloudProviderForm`，
/// 本 View 只负责渲染与提交。
@MainActor
public struct CustomCloudProviderEditor: View {
    @LumiTheme private var theme
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store: UserDefinedCloudProviderStore

    private let existingConfiguration: UserDefinedCloudProviderConfiguration?

    @State private var form: CustomCloudProviderForm
    @State private var errorMessage: String?

    private var apiFormats: [LLMProviderAPIFormat] { LLMProviderAPIFormat.allCases }

    public init(
        store: UserDefinedCloudProviderStore,
        configuration: UserDefinedCloudProviderConfiguration? = nil
    ) {
        self._store = ObservedObject(wrappedValue: store)
        self.existingConfiguration = configuration
        self._form = State(
            initialValue: configuration.map(CustomCloudProviderForm.init(configuration:))
                ?? CustomCloudProviderForm()
        )
    }

    public var body: some View {
        VStack(spacing: 0) {
            // MARK: Header
            HStack {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(existingConfiguration == nil ? "添加云端供应商" : "编辑云端供应商")
                        .font(DesignTokens.Typography.title2)
                        .foregroundColor(theme.textPrimary)
                    Text("配置兼容的 API 端点和模型列表")
                        .font(DesignTokens.Typography.caption1)
                        .foregroundColor(theme.textSecondary)
                }
                Spacer()
                HStack(spacing: DesignTokens.Spacing.sm) {
                    AppButton("取消", style: .secondary, size: .small) {
                        dismiss()
                    }
                    .accessibilityIdentifier(ProviderSettingsAccessibility.cancelButton)
                    AppButton("保存", style: .primary, size: .small) {
                        save()
                    }
                    .disabled(!form.canSave)
                    .accessibilityIdentifier(ProviderSettingsAccessibility.saveButton)
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.vertical, DesignTokens.Spacing.md)

            AppDivider()

            // MARK: Form
            ScrollView {
                VStack(spacing: DesignTokens.Spacing.md) {
                    // 基本信息
                    AppCard {
                        AppSettingsSection(title: "基本信息") {
                            AppInputField("供应商名称", text: $form.displayName)
                                .accessibilityIdentifier(ProviderSettingsAccessibility.nameField)
                            AppInputField("描述（可选）", text: $form.description)
                                .accessibilityIdentifier(ProviderSettingsAccessibility.descriptionField)
                            AppInputField("官网（可选）", text: $form.websiteURL)
                                .accessibilityIdentifier(ProviderSettingsAccessibility.websiteField)
                        }
                    }

                    // 连接
                    AppCard {
                        AppSettingsSection {
                            HStack {
                                Text("连接")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Picker("", selection: $form.apiFormat) {
                                    ForEach(apiFormats, id: \.self) { format in
                                        Text(Self.apiFormatTitle(format))
                                            .tag(format)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                                .fixedSize()
                                .accessibilityIdentifier(ProviderSettingsAccessibility.apiFormatPicker)
                            }
                            .padding(.bottom, 8)
                            AppInputField("API Endpoint URL", text: $form.baseURL)
                                .accessibilityIdentifier(ProviderSettingsAccessibility.baseURLField)
                        }
                    }

                    // 模型
                    AppCard {
                        AppSettingsSection(title: "模型") {
                            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                                Text("模型 ID（每行一个）")
                                    .font(DesignTokens.Typography.caption1)
                                    .foregroundColor(theme.textSecondary)
                                TextEditor(text: $form.modelIDsText)
                                    .font(DesignTokens.Typography.body.monospaced())
                                    .foregroundColor(theme.textPrimary)
                                    .frame(minHeight: 90)
                                    .padding(8)
                                    .background(
                                        RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous)
                                            .fill(theme.appListRowBackground)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous)
                                            .stroke(theme.appSubtleBorder, lineWidth: 1)
                                    )
                                    .accessibilityIdentifier(ProviderSettingsAccessibility.modelsField)
                            }
                        }
                    }

                    // Error
                    if let errorMessage {
                        AppErrorBanner(message: LocalizedStringKey(errorMessage))
                            .accessibilityIdentifier(ProviderSettingsAccessibility.errorBanner)
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.lg)
                .padding(.vertical, DesignTokens.Spacing.md)
            }
        }
    }

    private func save() {
        let configuration = form.makeConfiguration(existing: existingConfiguration)

        do {
            try store.upsert(configuration)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private static func apiFormatTitle(_ format: LLMProviderAPIFormat) -> String {
        switch format {
        case .openAI: return "OpenAI 兼容"
        case .anthropic: return "Anthropic 兼容"
        case .responses: return "OpenAI Responses"
        }
    }
}
