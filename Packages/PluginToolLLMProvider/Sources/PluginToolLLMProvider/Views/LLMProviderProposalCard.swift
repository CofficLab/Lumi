import KitLLM
import LumiUI
import ProviderLLMManager
import SwiftUI

/// 「添加 LLM 供应商」卡片：编辑端点与模型、填入 API Key、确认落库。
///
/// ## 与工具的关系
///
/// 卡片是提案的**唯一落库入口**。`add_llm_provider` 工具只产出提案，
/// 不写盘、不注册；只有用户在卡片上点「添加」，才会调用
/// `UserDefinedCloudProviderStore.upsert` 落盘并注册到运行时管理器。
///
/// ## API Key 的去向
///
/// API Key 只从卡片直接写进 Keychain（`SuperLLMProvider.setApiKey`），
/// 既不进入配置文件，也不进入对话记录，更不会被回传给模型。
struct LLMProviderProposalCard: View {
    @LumiTheme private var theme

    /// 草稿状态。必须是 `@StateObject`：消息列表重绘时会重新构造本视图，
    /// 用普通属性会让用户已经编辑过的内容被重置。
    @StateObject private var viewModel: LLMProviderProposalViewModel

    init(
        proposal: LLMProviderProposal,
        store: UserDefinedCloudProviderStore?,
        manager: (any LLMManaging)?
    ) {
        _viewModel = StateObject(
            wrappedValue: LLMProviderProposalViewModel(
                proposal: proposal,
                store: store,
                manager: manager
            )
        )
    }

    var body: some View {
        AppCard(style: .subtle, cornerRadius: 12, showShadow: false, borderIntensity: 0.06) {
            VStack(alignment: .leading, spacing: 10) {
                header
                fields
                errorBanner
                actionRow
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - 头部

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "server.rack")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(theme.primary)
            Text(pluginLocalization.string("Add LLM Provider"))
                .font(.appCaption)
                .foregroundColor(theme.textSecondary)
            Spacer(minLength: 0)
            Text(viewModel.apiFormat.rawValue)
                .font(.appMicro)
                .foregroundColor(theme.textSecondary)
        }
    }

    // MARK: - 表单

    private var fields: some View {
        VStack(alignment: .leading, spacing: 8) {
            labeledField(pluginLocalization.string("Provider Name")) {
                AppInputField(
                    localized("Provider Name"),
                    text: $viewModel.displayName
                )
            }

            labeledField(pluginLocalization.string("Endpoint")) {
                AppInputField(
                    localized("Endpoint"),
                    text: $viewModel.baseURL
                )
            }

            labeledField(pluginLocalization.string("API Format")) {
                Picker(
                    localized("API Format"),
                    selection: $viewModel.apiFormat
                ) {
                    ForEach(LLMProviderAPIFormat.allCases, id: \.self) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .font(.appCaption)
            }

            labeledField(pluginLocalization.string("Default Model")) {
                AppInputField(
                    localized("Default Model"),
                    text: $viewModel.defaultModel
                )
            }

            modelsEditor

            labeledField(pluginLocalization.string("API Key")) {
                AppInputField(
                    localized("API Key"),
                    text: $viewModel.apiKey,
                    fieldType: .secure
                )
            }
        }
    }

    /// 模型列表编辑器：已有模型以标签呈现，可删除；下方一行用于追加。
    private var modelsEditor: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(pluginLocalization.string("Models"))
                .font(.appMicro)
                .foregroundColor(theme.textSecondary)

            if viewModel.models.isEmpty {
                Text(pluginLocalization.string("No models yet — add at least one model id."))
                    .font(.appMicro)
                    .foregroundColor(theme.textSecondary)
            } else {
                modelTags
            }

            HStack(spacing: 6) {
                AppInputField(
                    localized("Model ID"),
                    text: $viewModel.pendingModelID
                )
                AppButton(
                    pluginLocalization.string("Add"),
                    systemImage: "plus",
                    style: .tonal,
                    size: .small
                ) {
                    viewModel.addPendingModel()
                }
            }
        }
    }

    private var modelTags: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(viewModel.models, id: \.id) { model in
                HStack(spacing: 6) {
                    Text(model.id)
                        .font(.appMicro)
                        .foregroundColor(theme.textPrimary)
                    Spacer(minLength: 0)
                    Button {
                        viewModel.removeModel(id: model.id)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(theme.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("lumi.llm-provider.remove-model.\(model.id)")
                }
            }
        }
    }

    /// 把插件本地化结果包成 `LocalizedStringKey`（LumiUI 的输入类组件要求该类型）。
    private func localized(_ key: String) -> LocalizedStringKey {
        LocalizedStringKey(pluginLocalization.string(key))
    }

    /// 带标题的字段容器。
    private func labeledField<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.appMicro)
                .foregroundColor(theme.textSecondary)
            content()
        }
    }

    // MARK: - 错误

    @ViewBuilder
    private var errorBanner: some View {
        if case .failed(let message) = viewModel.phase {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.appMicro)
                .foregroundColor(theme.error)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - 操作区

    @ViewBuilder
    private var actionRow: some View {
        switch viewModel.phase {
        case .editing, .failed:
            saveButton
        case .saving:
            savingIndicator
        case .saved:
            savedRow
        }
    }

    private var saveButton: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                AppButton(
                    pluginLocalization.string("Add Provider"),
                    systemImage: "plus.circle.fill",
                    style: .primary,
                    size: .small
                ) {
                    viewModel.save()
                }
                .disabled(!viewModel.hasValidModels)

                Text(pluginLocalization.string("The API key is stored in the keychain only."))
                    .font(.appMicro)
                    .foregroundColor(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if viewModel.isExistingProvider {
                Text(pluginLocalization.string("This provider already exists — saving replaces its configuration."))
                    .font(.appMicro)
                    .foregroundColor(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var savingIndicator: some View {
        HStack(spacing: 6) {
            ProgressView()
                .controlSize(.small)
            Text(pluginLocalization.string("Saving…"))
                .font(.appMicro)
                .foregroundColor(theme.textSecondary)
        }
    }

    private var savedRow: some View {
        HStack(spacing: 8) {
            Label(pluginLocalization.string("Added"), systemImage: "checkmark.circle.fill")
                .font(.appMicro)
                .foregroundColor(theme.success)
            Spacer(minLength: 0)
            AppButton(
                pluginLocalization.string("Use This Provider"),
                systemImage: "checkmark.circle",
                style: .tonal,
                size: .small
            ) {
                viewModel.selectAsCurrent()
            }
        }
    }
}

// MARK: - 预览

#Preview("LLM Provider Proposal Card") {
    LLMProviderProposalCard(
        proposal: LLMProviderProposal(
            id: "custom-acme",
            displayName: "Acme Gateway",
            providerDescription: "团队内部网关",
            baseURL: "https://api.acme.example.com/v1",
            apiFormat: .openAI,
            defaultModel: "acme-large",
            models: [
                UserDefinedCloudModel(id: "acme-large", displayName: "Acme Large"),
                UserDefinedCloudModel(id: "acme-small", displayName: "Acme Small"),
            ],
            websiteURLString: "https://acme.example.com"
        ),
        store: nil,
        manager: nil
    )
    .padding(20)
    .frame(width: 460)
}
