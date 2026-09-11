import Foundation
import LumiUI
import ProviderLLMManager
import KitLLM
import SwiftUI

/// 单个供应商的详情视图（API Key 段 + 模型段）。
///
/// - 云端供应商：API Key 读写/删除 + 模型列表（点击切换选中模型）；
/// - 本地供应商：仅模型列表（无需 API Key）。
@MainActor
public struct ProviderDetailView: View {
    @LumiTheme private var theme

    private let manager: any LLMManaging
    private let provider: any SuperLLMProvider
    private let customProviderStore: UserDefinedCloudProviderStore
    private let downloadViewModel: ProviderModelDownloadViewModel?

    @State private var apiKey: String = ""
    @State private var savedAPIKey: String = ""
    @State private var apiKeySaveError: String?
    @State private var isEditorPresented = false
    @State private var isDeleteConfirmationPresented = false

    public init(
        manager: any LLMManaging,
        provider: any SuperLLMProvider,
        customProviderStore: UserDefinedCloudProviderStore,
        downloadViewModel: ProviderModelDownloadViewModel? = nil
    ) {
        self.manager = manager
        self.provider = provider
        self.customProviderStore = customProviderStore
        self.downloadViewModel = downloadViewModel
    }

    private var info: LLMProviderInfo { provider.providerInfo }
    private var isLocal: Bool { info.isLocal }

    public var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            header
            if !isLocal {
                apiKeySection
            }
            if let downloader = provider as? any LLMModelDownloadProviding,
               let downloadViewModel {
                ProviderModelDownloadView(
                    models: info.models,
                    downloader: downloader,
                    viewModel: downloadViewModel,
                    onSelectModel: { modelID in
                        manager.select(providerID: info.id, model: modelID)
                    },
                    isModelSelected: { modelID in
                        manager.selectedProviderID == info.id && manager.selectedModel == modelID
                    }
                )
            } else {
                modelSection
            }
        }
        .onAppear {
            loadAPIKey()
        }
        .onChange(of: provider.providerInfo.id) { _, _ in
            loadAPIKey()
        }
        .sheet(isPresented: $isEditorPresented) {
            if let configuration = customProviderStore.configurations.first(where: { $0.id == info.id }) {
                CustomCloudProviderEditor(store: customProviderStore, configuration: configuration)
                    .frame(width: 580, height: 640)
            }
        }
        .confirmationDialog(
            "删除自定义供应商？",
            isPresented: $isDeleteConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                try? customProviderStore.remove(id: info.id)
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
                Image(systemName: isLocal ? "cpu" : "cloud.fill")
                    .font(.title3)
                    .foregroundStyle(theme.primary)
                Text(info.displayName)
                    .font(.appTitle)
                Spacer()
                if let url = info.websiteURL {
                    Link(destination: url) {
                        AppTag("访问官网", systemImage: "arrow.up.right.square", style: .accent)
                    }
                    .buttonStyle(.plain)
                }
                if customProviderStore.isCustomProvider(id: info.id) {
                    AppButton("编辑", systemImage: "pencil", style: .secondary, size: .small) {
                        isEditorPresented = true
                    }
                    AppButton("删除", systemImage: "trash", style: .destructive, size: .small) {
                        isDeleteConfirmationPresented = true
                    }
                }
            }
            if !info.description.isEmpty {
                Text(info.description)
                    .font(.appCaption)
                    .foregroundStyle(theme.textSecondary)
            }
            Text(info.id)
                .font(.appMicro)
                .foregroundStyle(theme.textTertiary)
                .textSelection(.enabled)
        }
    }

    // MARK: - API Key Section

    private var apiKeySection: some View {
        AppSettingSection(title: "API 密钥") {
            VStack(spacing: 0) {
                AppSettingRow(
                    title: "API Key",
                    description: "配置访问凭证",
                    icon: "key"
                ) {
                    SecureField("输入 API Key", text: $apiKey)
                        .textFieldStyle(.plain)
                        .font(.appBody)
                        .frame(width: 280)
                }

                Divider()
                    .padding(.vertical, 8)

                AppSettingRow(
                    title: "操作",
                    description: savedAPIKey.isEmpty ? "尚未保存 API Key" : "已保存 API Key"
                ) {
                    HStack(spacing: 8) {
                        AppButton("保存", systemImage: "checkmark", style: .primary, size: .small) {
                            saveAPIKey()
                        }
                        .disabled(
                            apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                || apiKey == savedAPIKey
                        )

                        if !savedAPIKey.isEmpty {
                            AppButton("删除", systemImage: "trash", style: .destructive, size: .small) {
                                removeAPIKey()
                            }
                        }

                        if !savedAPIKey.isEmpty, apiKey == savedAPIKey {
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

                if let apiKeySaveError {
                    Divider()
                        .padding(.vertical, 8)

                    AppSettingRow(
                        title: "错误",
                        description: apiKeySaveError
                    ) {
                        EmptyView()
                    }
                    .foregroundColor(theme.error)
                }
            }
        }
    }

    // MARK: - Model Section

    private var modelSection: some View {
        AppSettingSection(title: "可用模型") {
            VStack(spacing: 0) {
                ForEach(info.models.enumerated().map({ $0 }), id: \.element.id) { index, model in
                    if index > 0 {
                        Divider()
                            .padding(.vertical, 4)
                    }
                    modelRow(model)
                }
            }
        }
    }

    private func modelRow(_ model: LLMModelInfo) -> some View {
        let isSelected = manager.selectedProviderID == info.id && manager.selectedModel == model.id
        return AppSettingRow(
            title: model.displayName,
            description: model.contextWindowSize.map { "上下文 \(Self.formatted($0))" },
            icon: isSelected ? "checkmark.circle.fill" : (model.supportsVision ? "eye" : "cpu")
        ) {
            HStack(spacing: 6) {
                if model.supportsVision {
                    AppTag("视觉", systemImage: "eye", style: .accent)
                }
                if isSelected {
                    AppTag("当前", systemImage: "checkmark", style: .accent)
                }
            }
        }
        .onTapGesture {
            manager.select(providerID: info.id, model: model.id)
        }
    }

    // MARK: - API Key Actions

    private func loadAPIKey() {
        savedAPIKey = provider.getApiKey()
        apiKey = savedAPIKey
        apiKeySaveError = nil
    }

    private func saveAPIKey() {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        provider.setApiKey(trimmed)
        savedAPIKey = trimmed
        apiKey = trimmed
        apiKeySaveError = nil
    }

    private func removeAPIKey() {
        provider.removeApiKey()
        savedAPIKey = ""
        apiKey = ""
        apiKeySaveError = nil
    }

    // MARK: - Helpers

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
