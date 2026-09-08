import KitLLM
import LumiUI
import SwiftUI

/// 新增或编辑用户自定义云端供应商。
@MainActor
struct CustomCloudProviderEditor: View {
    @LumiTheme private var theme
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store: UserDefinedCloudProviderStore

    private let existingConfiguration: UserDefinedCloudProviderConfiguration?

    @State private var displayName: String
    @State private var description: String
    @State private var baseURL: String
    @State private var apiFormatIndex: Int
    @State private var modelIDs: String
    @State private var websiteURL: String
    @State private var errorMessage: String?

    private var apiFormats: [LLMProviderAPIFormat] { LLMProviderAPIFormat.allCases }
    private var apiFormat: LLMProviderAPIFormat { apiFormats[apiFormatIndex] }

    init(
        store: UserDefinedCloudProviderStore,
        configuration: UserDefinedCloudProviderConfiguration? = nil
    ) {
        self._store = ObservedObject(wrappedValue: store)
        self.existingConfiguration = configuration
        self._displayName = State(initialValue: configuration?.displayName ?? "")
        self._description = State(initialValue: configuration?.description ?? "")
        self._baseURL = State(initialValue: configuration?.baseURL ?? "")
        let initialFormat = configuration?.apiFormat ?? .openAI
        let initialIndex = LLMProviderAPIFormat.allCases.firstIndex(of: initialFormat) ?? 0
        self._apiFormatIndex = State(initialValue: initialIndex)
        self._modelIDs = State(initialValue: configuration?.models.map(\.id).joined(separator: "\n") ?? "")
        self._websiteURL = State(initialValue: configuration?.websiteURLString ?? "")
    }

    var body: some View {
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
                    AppButton("保存", style: .primary, size: .small) {
                        save()
                    }
                    .disabled(displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.vertical, DesignTokens.Spacing.md)

            AppDivider()

            // MARK: Form
            ScrollView {
                VStack(spacing: DesignTokens.Spacing.md) {
                    // 基本信息
                    AppSettingSection(title: "基本信息") {
                        AppInputField("供应商名称", text: $displayName)
                        AppInputField("描述（可选）", text: $description)
                        AppInputField("官网（可选）", text: $websiteURL)
                    }

                    // 连接
                    AppSettingSection {
                        HStack {
                            Text("连接")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Picker("", selection: $apiFormatIndex) {
                                ForEach(apiFormats.indices, id: \.self) { index in
                                    Text(Self.apiFormatTitle(apiFormats[index]))
                                        .tag(index)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .fixedSize()
                        }
                        .padding(.bottom, 8)
                        AppInputField("API Endpoint URL", text: $baseURL)
                    }

                    // 模型
                    AppSettingSection(title: "模型") {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                            Text("模型 ID（每行一个）")
                                .font(DesignTokens.Typography.caption1)
                                .foregroundColor(theme.textSecondary)
                            TextEditor(text: $modelIDs)
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
                        }
                    }

                    // Error
                    if let errorMessage {
                        AppErrorBanner(message: LocalizedStringKey(errorMessage))
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.lg)
                .padding(.vertical, DesignTokens.Spacing.md)
            }
        }
    }

    private func save() {
        let ids = modelIDs
            .split(whereSeparator: { $0 == "\n" || $0 == "," })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let oldModels = Dictionary(uniqueKeysWithValues: (existingConfiguration?.models ?? []).map { ($0.id, $0) })
        let models = ids.map { id in
            oldModels[id] ?? UserDefinedCloudModel(id: id)
        }
        let resolvedDefaultModel = models.first?.id ?? ""
        let configuration = UserDefinedCloudProviderConfiguration(
            id: existingConfiguration?.id ?? "user-\(UUID().uuidString.lowercased())",
            displayName: displayName,
            description: description,
            baseURL: baseURL,
            apiFormat: apiFormat,
            defaultModel: resolvedDefaultModel,
            models: models,
            websiteURLString: websiteURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : websiteURL
        )

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
