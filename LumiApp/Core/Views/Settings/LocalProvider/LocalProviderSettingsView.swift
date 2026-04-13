import AppKit
import MagicKit
import SwiftUI

/// 本地大模型设置视图（仅展示本地模型供应商）
struct LocalProviderSettingsView: View {
    // MARK: - State

    /// 当前选中的本地供应商 ID
    @State private var selectedProviderId: String = ""

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

    @EnvironmentObject private var registry: LLMProviderRegistry

    // MARK: - Constants

    private static let selectedLocalProviderKey = "LocalProviderSettingsView.selectedProviderId"

    // MARK: - Computed

    /// 所有本地供应商（过滤掉非本地的）
    private var localProviders: [LLMProviderInfo] {
        registry
            .allProviders()
            .filter { info in
                // 只保留可以创建出本地 provider 的项
                (registry.createProvider(id: info.id) as? any SuperLocalLLMProvider) != nil
            }
    }

    /// 当前供应商类型
    private var selectedProviderType: (any SuperLLMProvider.Type)? {
        registry.providerType(forId: selectedProviderId)
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // 本地供应商卡片（固定）
            providerSelectorCard
                .padding(AppUI.Spacing.lg)
                .background(Color.clear)

            ScrollView {
                VStack(alignment: .leading, spacing: AppUI.Spacing.lg) {
                    // 本地模型管理卡片
                    if localProvider != nil {
                        localModelCard
                    }

                    Spacer()
                }
                .padding(.horizontal, AppUI.Spacing.lg)
            }
        }
        .onAppear(perform: onAppear)
        .onChange(of: selectedProviderId) { _, _ in
            loadSettings()
            updateLocalProvider()
        }
    }
}

// MARK: - View

extension LocalProviderSettingsView {
    /// 本地供应商选择器卡片（固定）
    private var providerSelectorCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: AppUI.Spacing.md) {
                GlassSectionHeader(
                    icon: "cpu.fill",
                    title: "本地 LLM 供应商",
                    subtitle: "在本地设备上运行 AI 模型"
                )

                if localProviders.count > 1 {
                    GlassDivider()

                    HStack(spacing: AppUI.Spacing.sm) {
                        ForEach(localProviders) { provider in
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
        }
    }

    /// 本地模型管理卡片
    private var localModelCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 0) {
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
                       selectedSeriesName.isEmpty || !localAvailableModels.contains(where: { ($0.series ?? "其他") == selectedSeriesName }) {
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
                .task(id: localProvider != nil ? "poll-local" : "nop-local") {
                    guard localProvider != nil else { return }
                    while !Task.isCancelled {
                        localDownloadStatus = localProvider?.getDownloadStatus() ?? .idle
                        loadedModelId = await localProvider?.getLoadedModelId()
                        try? await Task.sleep(for: .milliseconds(350))
                    }
                }
            }
        }
    }
}

// MARK: - Actions

extension LocalProviderSettingsView {
    /// 加载当前供应商的设置信息（选中的模型）
    private func loadSettings() {
    }

    /// 保存选中的模型到 UserDefaults
    private func saveModel() {
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
        localAvailableModels = await local.getAvailableModels()
        localCachedIds = await local.getCachedModels()
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

// MARK: - Lifecycle

extension LocalProviderSettingsView {
    /// 视图出现时的事件处理 - 加载仅本地供应商的设置
    func onAppear() {
        selectedProviderId = localProviders.first?.id ?? ""
        loadSettings()
        updateLocalProvider()
    }
}

// MARK: - Preview

#Preview("Local Provider Settings") {
    LocalProviderSettingsView()
        .inRootView()
}

#Preview("Local Provider Settings - Full App") {
    ContentLayout()
        .hideSidebar()
        .inRootView()
}
