import Foundation
import LumiUI
import KitLLM
import SwiftUI

/// 单个供应商的详情视图（API Key 段 + 模型段）。
///
/// - 云端供应商：API Key 读写/删除 + 模型列表（点击切换选中模型）；
/// - 本地供应商：仅模型列表（无需 API Key）。
///
/// View 只依赖 `ProviderDetailViewModel`，不再直接持有 manager / Provider / Store，
/// 也不对外部 Provider 做 downcast（下载能力由 ViewModel 解析）。
@MainActor
public struct ProviderDetailView: View {
    @LumiTheme private var theme

    @ObservedObject private var viewModel: ProviderDetailViewModel
    @State private var isEditorPresented = false
    @State private var isDeleteConfirmationPresented = false
    /// API Key 是否以明文展示（仅本地 UI 状态，不落盘）。
    @State private var isAPIKeyRevealed = false
    /// 复制 API Key 后短暂显示「已复制」反馈。
    @State private var isAPIKeyCopied = false

    init(viewModel: ProviderDetailViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            if !viewModel.isLocal {
                apiKeySection
            }
            if let downloadViewModel = viewModel.downloadViewModel,
               let capability = viewModel.downloadCapability {
                ProviderModelDownloadView(
                    models: viewModel.models,
                    capability: capability,
                    viewModel: downloadViewModel,
                    onSelectModel: { modelID in
                        viewModel.select(modelID: modelID)
                    },
                    isModelSelected: { modelID in
                        viewModel.isModelSelected(modelID)
                    }
                )
            } else {
                modelSection
            }
            if let modelRefreshError = viewModel.modelRefreshError {
                AppErrorBanner(message: LocalizedStringKey(modelRefreshError))
            }
        }
        .sheet(isPresented: $isEditorPresented) {
            if let editor = viewModel.makeCustomProviderEditor() {
                editor
                    .frame(width: 580, height: 640)
            }
        }
        .confirmationDialog(
            "删除自定义供应商？",
            isPresented: $isDeleteConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                viewModel.removeCustomProvider()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("这会移除供应商配置和对应的 API Key。")
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: viewModel.isLocal ? "cpu" : "cloud.fill")
                    .font(.title3)
                    .foregroundStyle(theme.primary)
                Text(viewModel.displayName)
                    .font(.appTitle)
                Spacer()
                if let url = viewModel.websiteURL {
                    Link(destination: url) {
                        AppTag("访问官网", systemImage: "arrow.up.right.square", style: .accent)
                    }
                    .buttonStyle(.plain)
                }
                if viewModel.canEditCustomProvider {
                    AppButton("编辑", systemImage: "pencil", style: .secondary, size: .small) {
                        isEditorPresented = true
                    }
                    .accessibilityIdentifier(ProviderSettingsAccessibility.editProviderButton)
                    AppButton("删除", systemImage: "trash", style: .destructive, size: .small) {
                        isDeleteConfirmationPresented = true
                    }
                }
                if viewModel.canRefreshModels {
                    AppButton(
                        pluginLocalization.string(
                            viewModel.isRefreshingModels ? "刷新中…" : "刷新模型列表"
                        ),
                        systemImage: "arrow.clockwise",
                        style: .secondary,
                        size: .small
                    ) {
                        Task { await viewModel.refreshModels() }
                    }
                    .disabled(viewModel.isRefreshingModels)
                    .help(pluginLocalization.string("从供应商拉取最新的模型列表"))
                    .accessibilityIdentifier(ProviderSettingsAccessibility.refreshModelsButton)
                }
            }
            if !viewModel.providerDescription.isEmpty {
                Text(viewModel.providerDescription)
                    .font(.appCaption)
                    .foregroundStyle(theme.textSecondary)
            }
            Text(viewModel.providerID)
                .font(.appMicro)
                .foregroundStyle(theme.textTertiary)
                .textSelection(.enabled)
        }
    }

    // MARK: - API Key Section

    private var apiKeySection: some View {
        AppCard {
            AppSettingsSection(title: "API 密钥") {
                AppSettingsRow {
                    HStack(spacing: 12) {
                        Image(systemName: "key")
                            .font(.appCallout)
                            .foregroundColor(theme.primary)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("API Key")
                                .font(.appBody)
                                .foregroundColor(theme.textPrimary)
                            Text("配置访问凭证")
                                .font(.appCaption)
                                .foregroundColor(theme.textSecondary)
                        }

                        Spacer()

                        HStack(spacing: 6) {
                            Group {
                                if isAPIKeyRevealed {
                                    TextField("输入 API Key", text: $viewModel.apiKey)
                                } else {
                                    SecureField("输入 API Key", text: $viewModel.apiKey)
                                }
                            }
                            .textFieldStyle(.plain)
                            .font(.appBody)
                            .frame(width: 260)
                        }
                    }
                }

                AppSettingsRow {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("操作")
                                .font(.appBody)
                                .foregroundColor(theme.textPrimary)
                            Text(viewModel.savedAPIKey.isEmpty ? "尚未保存 API Key" : "已保存 API Key")
                                .font(.appCaption)
                                .foregroundColor(theme.textSecondary)
                        }

                        Spacer()

                        HStack(spacing: 8) {
                            if !viewModel.savedAPIKey.isEmpty {
                                AppIconButton(
                                    systemImage: isAPIKeyRevealed ? "eye.slash" : "eye"
                                ) {
                                    isAPIKeyRevealed.toggle()
                                }
                                .help(isAPIKeyRevealed ? "隐藏 API Key" : "显示 API Key")
                            }

                            if !copyableAPIKey.isEmpty {
                                AppIconButton(
                                    systemImage: isAPIKeyCopied ? "checkmark" : "doc.on.doc",
                                    tint: isAPIKeyCopied ? theme.success : nil
                                ) {
                                    copyAPIKey()
                                }
                                .help(isAPIKeyCopied ? "已复制" : "复制 API Key")
                                .accessibilityIdentifier(ProviderSettingsAccessibility.copyAPIKeyButton)
                            }

                            AppButton("保存", systemImage: "checkmark", style: .primary, size: .small) {
                                viewModel.saveAPIKey()
                            }
                            .disabled(
                                viewModel.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    || viewModel.apiKey == viewModel.savedAPIKey
                            )

                            if !viewModel.savedAPIKey.isEmpty {
                                AppButton("删除", systemImage: "trash", style: .destructive, size: .small) {
                                    viewModel.removeAPIKey()
                                }
                            }

                            if !viewModel.savedAPIKey.isEmpty, viewModel.apiKey == viewModel.savedAPIKey {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(theme.success)
                                        .font(.appCaption)
                                    Text("已保存")
                                        .font(.appCaption)
                                        .foregroundColor(theme.success)
                                }
                            }
                        }
                    }
                }

                if let apiKeySaveError = viewModel.apiKeySaveError {
                    AppSettingsRow {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("错误")
                                    .font(.appBody)
                                    .foregroundColor(theme.textPrimary)
                                Text(apiKeySaveError)
                                    .font(.appCaption)
                                    .foregroundColor(theme.textSecondary)
                            }

                            Spacer()

                            EmptyView()
                        }
                    }
                    .foregroundColor(theme.error)
                }
            }
        }
    }

    // MARK: - Model Section

    private var modelSection: some View {
        AppCard {
            AppSettingsSection(title: "可用模型") {
                ForEach(viewModel.models.enumerated().map({ $0 }), id: \.element.id) { _, model in
                    modelRow(model)
                }
            }
        }
    }

    private func modelRow(_ model: LLMModelInfo) -> some View {
        let isSelected = viewModel.isModelSelected(model.id)
        return AppSettingsRow {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : (model.supportsVision ? "eye" : "cpu"))
                    .font(.appCallout)
                    .foregroundColor(theme.primary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(model.displayName)
                        .font(.appBody)
                        .foregroundColor(theme.textPrimary)
                    if let contextWindow = model.contextWindowSize.map({ "上下文 \(Self.formatted($0))" }) {
                        Text(contextWindow)
                            .font(.appCaption)
                            .foregroundColor(theme.textSecondary)
                    }
                }

                Spacer()

                HStack(spacing: 6) {
                    if model.supportsVision {
                        AppTag("视觉", systemImage: "eye", style: .accent)
                    }
                    if isSelected {
                        AppTag("当前", systemImage: "checkmark", style: .accent)
                    }
                }
            }
        }
        .onTapGesture {
            viewModel.select(modelID: model.id)
        }
    }

    // MARK: - Helpers

    /// 可复制的 API Key：优先已保存的值，无已保存值时复制输入框里的当前内容。
    private var copyableAPIKey: String {
        let saved = viewModel.savedAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !saved.isEmpty {
            return saved
        }
        return viewModel.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func copyAPIKey() {
        let value = copyableAPIKey
        guard !value.isEmpty else { return }
        LumiPasteboard.copyString(value)
        isAPIKeyCopied = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            isAPIKeyCopied = false
        }
    }

    private static func formatted(_ tokens: Int) -> String {
        if tokens >= 1_000_000 {
            let m = Double(tokens) / 1_000_000
            return String(format: "%.1fM", m)
        }
        if tokens >= 1_000 {
            return "\(tokens / 1_000)K"
        }
        return "\(tokens)"
    }
}
