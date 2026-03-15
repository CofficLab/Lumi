import SwiftUI
import MagicKit
import AppKit

/// 供应商设置视图 - 配置 LLM 供应商的 API 密钥和模型选择
struct ProviderSettingsView: View, SuperLog {
    // MARK: - SuperLog

    nonisolated static let emoji = "⚙️"
    nonisolated static let verbose = false

    // MARK: - Constants

    private static let selectedProviderKey = "ProviderSettingsView.selectedProviderId"

    // MARK: - State

    /// 当前选中的供应商 ID
    @State private var selectedProviderId: String = ""
    
    /// API Key 输入
    @State private var apiKey: String = ""
    
    /// 选中的模型
    @State private var selectedModel: String = ""

    /// 当前选中的本地供应商实例（用于展示本地模型列表、下载、加载）
    @State private var localProvider: (any SuperLocalLLMProvider)?
    /// 本地可用模型列表
    @State private var localAvailableModels: [LocalModelInfo] = []
    /// 已缓存模型 ID
    @State private var localCachedIds: Set<String> = []
    /// 本地模型加载中
    @State private var localModelsLoading = false
    /// 下载/加载错误信息
    @State private var localActionError: String?
    /// 当前正在下载的模型 ID（用于显示该行进度）
    @State private var downloadingModelId: String?
    /// 轮询得到的下载状态（用于 UI 实时更新）
    @State private var localDownloadStatus: LocalDownloadStatus = .idle
    /// 当前已加载到内存的模型 ID（用于加载/卸载按钮状态）
    @State private var loadedModelId: String?
    /// 当前正在加载到内存的模型 ID（用于显示加载中动画）
    @State private var loadingModelId: String?
    /// 当前选中的本地模型系列 Tab（如「Qwen 系列」）
    @State private var selectedSeriesName: String = ""
    /// 是否显示「已卸载」成功反馈（短暂显示后自动隐藏）
    @State private var showUnloadSuccess = false

    // MARK: - Environment

    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Dependencies

    @EnvironmentObject private var registry: ProviderRegistry

    // MARK: - Computed Properties

    /// 当前选中的供应商信息
    private var selectedProvider: ProviderInfo? {
        registry.allProviders().first(where: { $0.id == selectedProviderId })
    }

    /// 当前供应商类型
    private var selectedProviderType: (any SuperLLMProvider.Type)? {
        registry.providerType(forId: selectedProviderId)
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                // 供应商选择器
                providerSelector

                // 供应商信息卡片
                providerInfoCard

                // 远程：API Key + 可用模型列表；本地：已加载/列表/下载/加载
                if localProvider != nil {
                    LocalModelSectionView(
                        localProvider: localProvider,
                        selectedModel: $selectedModel,
                        selectedSeriesName: $selectedSeriesName,
                        localAvailableModels: localAvailableModels,
                        localCachedIds: localCachedIds,
                        localModelsLoading: localModelsLoading,
                        localActionError: localActionError,
                        downloadingModelId: downloadingModelId,
                        localDownloadStatus: localDownloadStatus,
                        loadedModelId: loadedModelId,
                        loadingModelId: loadingModelId,
                        showUnloadSuccess: showUnloadSuccess,
                        onSaveModel: saveModel,
                        onDownload: downloadLocalModel,
                        onLoad: loadLocalModel,
                        onUnload: unloadLocalModel,
                        onOpenCacheDirectory: {
                            guard let local = localProvider else { return }
                            NSWorkspace.shared.open(local.getCacheDirectoryURL())
                        }
                    )
                    .onChange(of: localAvailableModels.count) { _, count in
                        if count > 0,
                           (selectedSeriesName.isEmpty || !localAvailableModels.contains(where: { ($0.series ?? "其他") == selectedSeriesName })) {
                            let fallback = "其他"
                            let grouped = Dictionary(grouping: localAvailableModels) { $0.series ?? fallback }
                            selectedSeriesName = grouped.keys.sorted().first ?? ""
                        }
                    }
                    .task(id: selectedProviderId) {
                        await refreshLocalModels()
                        if !localAvailableModels.isEmpty {
                            let fallback = "其他"
                            let grouped = Dictionary(grouping: localAvailableModels) { $0.series ?? fallback }
                            selectedSeriesName = grouped.keys.sorted().first ?? ""
                        }
                    }
                    .task(id: localProvider != nil ? "poll" : "nop") {
                        guard localProvider != nil else { return }
                        while !Task.isCancelled {
                            localDownloadStatus = localProvider?.getDownloadStatus() ?? .idle
                            loadedModelId = await localProvider?.getLoadedModelId()
                            try? await Task.sleep(for: .milliseconds(350))
                        }
                    }
                } else {
                    RemoteModelSectionView(
                        selectedProvider: selectedProvider,
                        selectedModel: $selectedModel,
                        apiKey: $apiKey,
                        onSelectModel: saveModel
                    )
                }

                Spacer()
            }
            .padding(DesignTokens.Spacing.lg)
        }
        .onAppear(perform: onAppear)
        .onChange(of: selectedProviderId) { _, newValue in
            // 保存选中的供应商 ID
            AppSettingsStore.shared.set(newValue, forKey: Self.selectedProviderKey)
            loadSettings()
            updateLocalProvider()
        }
        .onChange(of: apiKey) { _, _ in
            saveApiKey()
        }
    }
}

// MARK: - View

extension ProviderSettingsView {
    /// 供应商选择器 - 显示所有可用的 LLM 供应商按钮
    private var providerSelector: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("LLM 供应商")
                .font(DesignTokens.Typography.callout)
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)

            HStack(spacing: DesignTokens.Spacing.sm) {
                ForEach(registry.allProviders()) { provider in
                    ProviderButton(
                        provider: provider,
                        isSelected: selectedProviderId == provider.id
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedProviderId = provider.id
                        }
                    }
                }
            }
        }
    }

    /// 供应商信息卡片 - 显示当前选中供应商的图标、名称和描述
    private var providerInfoCard: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: selectedProvider?.iconName ?? "dot.square")
                .font(.system(size: 28))
                .foregroundStyle(
                    LinearGradient(
                        colors: [DesignTokens.Color.semantic.primary, DesignTokens.Color.semantic.primarySecondary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(DesignTokens.Color.semantic.primary.opacity(0.1))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(selectedProvider?.displayName ?? "未知供应商")
                    .font(DesignTokens.Typography.callout)
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                Text(selectedProvider?.description ?? "")
                    .font(DesignTokens.Typography.caption1)
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)
            }

            Spacer()
        }
        .padding(DesignTokens.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                .fill(DesignTokens.Material.glass)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }

}

// MARK: - Action

extension ProviderSettingsView {
    /// 加载当前供应商的设置信息（API Key 和选中的模型）
    private func loadSettings() {
        guard let providerType = selectedProviderType else { return }

        apiKey = AppSettingsStore.shared.string(forKey: providerType.apiKeyStorageKey) ?? ""
        selectedModel = AppSettingsStore.shared.string(forKey: providerType.modelStorageKey)
            ?? providerType.defaultModel
    }

    /// 保存 API Key 到 UserDefaults
    private func saveApiKey() {
        guard let providerType = selectedProviderType else { return }
        AppSettingsStore.shared.set(apiKey, forKey: providerType.apiKeyStorageKey)
    }

    /// 保存选中的模型到 UserDefaults
    private func saveModel() {
        guard let providerType = selectedProviderType else { return }
        AppSettingsStore.shared.set(selectedModel, forKey: providerType.modelStorageKey)
    }

    /// 根据当前选中的供应商 ID 更新本地供应商引用
    private func updateLocalProvider() {
        localProvider = registry.createProvider(id: selectedProviderId) as? any SuperLocalLLMProvider
        if localProvider == nil {
            loadedModelId = nil
            loadingModelId = nil
            showUnloadSuccess = false
        }
        localActionError = nil
    }

    /// 刷新本地模型列表与已缓存集合
    private func refreshLocalModels() async {
        guard let local = localProvider else {
            localAvailableModels = []
            localCachedIds = []
            return
        }
        localModelsLoading = true
        localActionError = nil
        defer { localModelsLoading = false }
        do {
            localAvailableModels = await local.getAvailableModels()
            localCachedIds = await local.getCachedModels()
        } catch {
            localActionError = error.localizedDescription
        }
    }

    private func downloadLocalModel(id: String) async {
        guard let local = localProvider else { return }
        localActionError = nil
        downloadingModelId = id
        defer { downloadingModelId = nil }
        do {
            try await local.downloadModel(id: id)
            localCachedIds = await local.getCachedModels()
        } catch {
            localActionError = error.localizedDescription
        }
    }

    private func loadLocalModel(id: String) async {
        guard let local = localProvider else { return }
        localActionError = nil
        withAnimation(.easeInOut(duration: 0.25)) {
            loadingModelId = id
        }
        defer {
            withAnimation(.easeInOut(duration: 0.25)) {
                loadingModelId = nil
            }
        }
        do {
            try await local.loadModel(id: id)
            selectedModel = id
            saveModel()
        } catch {
            localActionError = error.localizedDescription
        }
    }

    private func unloadLocalModel() async {
        guard let local = localProvider else { return }
        localActionError = nil
        await local.unloadModel()
        await MainActor.run {
            showUnloadSuccess = true
            Task {
                try? await Task.sleep(for: .seconds(2))
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.2)) {
                        showUnloadSuccess = false
                    }
                }
            }
        }
    }
}

// MARK: - Event Handler

extension ProviderSettingsView {
    /// 视图出现时的事件处理 - 加载供应商设置
    func onAppear() {
        // 读取上次选中的供应商
        if let savedProviderId = AppSettingsStore.shared.string(forKey: Self.selectedProviderKey),
           !savedProviderId.isEmpty {
            selectedProviderId = savedProviderId
        } else {
            // 如果没有保存的值，使用第一个供应商作为默认
            let allProviders = registry.allProviders()
            selectedProviderId = allProviders.first?.id ?? ""
        }
        loadSettings()
        updateLocalProvider()
    }
}

// MARK: - Preview

#Preview("App - Small Screen") {
    ProviderSettingsView()
        .inRootView()
        .frame(width: 500)
        .frame(height: 600)
}

#Preview("App - Big Screen") {
    ProviderSettingsView()
        .inRootView()
        .frame(width: 1200)
        .frame(height: 1200)
}
