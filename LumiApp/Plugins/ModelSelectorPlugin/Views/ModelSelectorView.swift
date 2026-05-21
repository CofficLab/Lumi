import AppKit
import MagicKit
import LLMKit
import SwiftUI
import LumiUI

/// 模型选择器视图
/// 允许用户从所有已注册的供应商和模型中选择
struct ModelSelectorView: View, SuperLog {
    /// 日志标识 emoji
    nonisolated static let emoji = "🌐"
    /// 是否输出详细日志
    nonisolated static let verbose: Bool = false
    /// 环境对象：用于关闭当前视图
    @Environment(\.dismiss) private var dismiss

    @EnvironmentObject var llmVM: AppLLMVM
    @EnvironmentObject var chatHistoryVM: AppChatHistoryVM
    @EnvironmentObject var conversationVM: WindowConversationVM
    @ObservedObject private var availabilityStore = LLMAvailabilityStore.shared

    /// 模型性能统计
    @State private var detailedStats: [String: ModelPerformanceStats] = [:]

    /// 当前选中的 Tab，默认显示当前供应商
    @State private var selectedTab: ModelSelectorTab = .current

    /// 当前 hover 的模型
    @State private var hoveringModelId: String? = nil

    /// 常用模型列表（跨供应商，按使用频率排序）
    @State private var frequentModels: [FrequentModelEntry] = []

    /// TPS 较快的模型列表
    @State private var fastModels: [FastModelEntry] = []

    /// 搜索关键词（用于过滤模型/供应商）
    @State private var searchText: String = ""

    /// 本地供应商的模型详情（按 providerId -> [LocalModelInfo]），用于按系列展示
    @State private var localModelInfosByProvider: [String: [LocalModelInfo]] = [:]

    /// 统计数据是否已加载完成
    @State private var isStatsLoaded = false

    /// 本地模型详情是否正在加载
    @State private var isLoadingLocalModels = false

    /// 当前供应商信息
    private var currentProvider: LLMProviderInfo? {
        llmVM.allProviders.first(where: { $0.id == llmVM.selectedProviderId })
    }

    var body: some View {
        HStack(spacing: 0) {
            ModelSelectorTabSidebar(
                providers: llmVM.allProviders,
                selectedProviderId: llmVM.selectedProviderId,
                selectedTab: $selectedTab
            )
            .frame(width: 300)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            VStack(spacing: 0) {
                ModelSelectorSearchBar(
                    searchText: $searchText,
                    onCancel: { dismiss() }
                )

                Divider()

                Group {
                    switch selectedTab {
                    case .current:
                        currentProviderList
                    case .frequent:
                        frequentModelsList
                    case .fast:
                        fastModelsList
                    case .auto:
                        AutoTabContent()
                    case .availability:
                        AvailabilityTabContent()
                    case .all:
                        providerList(
                            providers: ModelSelectorFilteringService.filteredProviders(
                                from: llmVM.allProviders,
                                searchText: searchText,
                                localModelInfosByProvider: localModelInfosByProvider
                            ),
                            emptyMessage: String(localized: "No Providers", table: "AgentChat")
                        )
                    case .provider(let providerId):
                        singleProviderList(providerId: providerId)
                    }
                }
                .listStyle(.sidebar)
            }
        }
        .frame(width: 600, height: 800)
        .background(Material.regularMaterial)
        .task {
            await loadAllStats()
        }
        .task(id: selectedTab) {
            switch selectedTab {
            case .current:
                if currentProvider?.isLocal == true {
                    await loadLocalModelInfos(providerIds: [llmVM.selectedProviderId])
                }
            case .provider(let providerId):
                if let provider = llmVM.allProviders.first(where: { $0.id == providerId }), provider.isLocal {
                    await loadLocalModelInfos(providerIds: [providerId])
                }
            case .all:
                let localIds = llmVM.allProviders.filter(\.isLocal).map(\.id)
                await loadLocalModelInfos(providerIds: localIds)
            case .auto, .availability, .frequent, .fast:
                break
            }
        }
    }

    // MARK: - Single Provider List

    /// 单个供应商的模型列表
    @ViewBuilder
    private func singleProviderList(providerId: String) -> some View {
        if let provider = llmVM.allProviders.first(where: { $0.id == providerId }),
           ModelSelectorFilteringService.hasVisibleModels(
               provider: provider,
               searchText: searchText,
               localModelInfosByProvider: localModelInfosByProvider
           ) {
            List {
                Section(header: sectionHeader(for: provider)) {
                    modelSectionContent(for: provider)
                }
            }
        } else {
            AppEmptyState(
                icon: "magnifyingglass",
                title: "No Matching Models",
                description: nil
            )
        }
    }

    // MARK: - Current Provider List

    /// 当前供应商的模型列表
    @ViewBuilder
    private var currentProviderList: some View {
        if let provider = currentProvider {
            if ModelSelectorFilteringService.hasVisibleModels(
                provider: provider,
                searchText: searchText,
                localModelInfosByProvider: localModelInfosByProvider
            ) {
                List {
                    Section(header: sectionHeader(for: provider)) {
                        modelSectionContent(for: provider)
                    }
                }
            } else {
                AppEmptyState(
                    icon: "magnifyingglass",
                    title: "No Matching Models",
                    description: nil
                )
            }
        } else {
            AppEmptyState(
                icon: "tray",
                title: "No Provider Selected",
                description: nil
            )
        }
    }

    // MARK: - Frequent Models List

    /// 常用模型列表（跨供应商，按使用频率排序）
    @ViewBuilder
    private var frequentModelsList: some View {
        let filteredEntries = ModelSelectorFilteringService.filteredFrequentModels(frequentModels, searchText: searchText)
        if filteredEntries.isEmpty {
            AppEmptyState(
                icon: "clock.arrow.circlepath",
                title: "No Frequent Models",
                description: "No Frequent Models Description"
            )
        } else {
            List {
                ForEach(filteredEntries) { entry in
                    frequentModelRow(entry: entry)
                }
            }
        }
    }

    /// 常用模型的单行视图
    private func frequentModelRow(entry: FrequentModelEntry) -> some View {
        guard let provider = llmVM.allProviders.first(where: { $0.id == entry.providerId }) else {
            return AnyView(EmptyView())
        }
        return AnyView(
            modelRow(
                provider: provider,
                model: entry.modelName,
                providerDisplayName: entry.providerDisplayName
            )
        )
    }

    // MARK: - Fast Models List

    /// TPS 较快模型列表（跨供应商，按 TPS 降序，最多 10 个）
    @ViewBuilder
    private var fastModelsList: some View {
        let filteredEntries = ModelSelectorFilteringService.filteredFastModels(fastModels, searchText: searchText)
        if filteredEntries.isEmpty {
            AppEmptyState(
                icon: "bolt.fill",
                title: "No Fast Models",
                description: "No Fast Models Description"
            )
        } else {
            List {
                ForEach(filteredEntries) { entry in
                    fastModelRow(entry: entry)
                }
            }
        }
    }

    /// TPS 较快模型单行
    private func fastModelRow(entry: FastModelEntry) -> some View {
        guard let provider = llmVM.allProviders.first(where: { $0.id == entry.providerId }) else {
            return AnyView(EmptyView())
        }
        return AnyView(
            modelRow(
                provider: provider,
                model: entry.modelName,
                providerDisplayName: entry.providerDisplayName
            )
        )
    }

    /// 供应商与模型列表（共用结构）；本地供应商有缓存时按系列分组展示
    @ViewBuilder
    private func providerList(providers: [LLMProviderInfo], emptyMessage: String) -> some View {
        if providers.isEmpty {
            AppEmptyState(
                icon: "tray",
                title: LocalizedStringKey(emptyMessage),
                description: nil
            )
        } else {
            List {
                ForEach(providers) { provider in
                    Section(header: sectionHeader(for: provider)) {
                        modelSectionContent(for: provider)
                    }
                }
            }
        }
    }

    // MARK: - Model Section Content

    /// 供应商下的模型列表内容（共用，支持本地按系列分组 / 远程平铺）
    @ViewBuilder
    private func modelSectionContent(for provider: LLMProviderInfo) -> some View {
        if provider.isLocal, let infos = localModelInfosByProvider[provider.id], !infos.isEmpty {
            let filteredInfos = ModelSelectorFilteringService.filteredLocalModelInfos(
                infos,
                provider: provider,
                searchText: searchText
            )
            let fallbackSeries = String(localized: "Other", table: "AgentChat")
            let grouped = Dictionary(grouping: filteredInfos) { $0.series ?? fallbackSeries }
            ForEach(grouped.keys.sorted(), id: \.self) { seriesName in
                Section(header: Text(seriesName).font(.system(size: 13, weight: .regular)).foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))) {
                    ForEach(grouped[seriesName] ?? [], id: \.id) { info in
                        modelRow(
                            provider: provider,
                            model: info.id,
                            displayName: info.displayName,
                            supportsVision: info.supportsVision,
                            supportsTools: info.supportsTools
                        )
                    }
                }
            }
        } else {
            let filteredModels = ModelSelectorFilteringService.filteredModels(for: provider, searchText: searchText)
            ForEach(filteredModels, id: \.self) { model in
                let caps = ModelSelectorFilteringService.capabilityValues(
                    provider: provider,
                    model: model,
                    providerType: llmVM.providerType(forId: provider.id)
                )
                modelRow(
                    provider: provider,
                    model: model,
                    supportsVision: caps.supportsVision,
                    supportsTools: caps.supportsTools
                )
            }
        }
    }

    /// 单行模型
    private func modelRow(
        provider: LLMProviderInfo,
        model: String,
        displayName: String? = nil,
        providerDisplayName: String? = nil,
        supportsVision: Bool? = nil,
        supportsTools: Bool? = nil
    ) -> some View {
        let hoverKey = "\(provider.id)|\(model)"
        return ModelSelectorModelRow(
            provider: provider,
            model: model,
            displayName: displayName,
            providerDisplayName: providerDisplayName,
            supportsVision: supportsVision,
            supportsTools: supportsTools,
            isSelected: isSelected(providerId: provider.id, model: model),
            isHovering: hoveringModelId == hoverKey,
            stat: findDetailedStat(providerId: provider.id, modelName: model),
            availabilityStatus: availabilityStore.status(providerId: provider.id, modelId: model),
            onSelect: {
                selectModel(providerId: provider.id, model: model)
            },
            onHoverChange: { hovering in
                if hovering {
                    hoveringModelId = hoverKey
                } else if hoveringModelId == hoverKey {
                    hoveringModelId = nil
                }
            }
        )
    }
}

// MARK: - View

extension ModelSelectorView {
    /// 构建供应商分组头部视图
    /// - Parameter provider: 供应商信息
    /// - Returns: 包含供应商图标和名称的头部视图
    @ViewBuilder
    private func sectionHeader(for provider: LLMProviderInfo) -> some View {
        HStack {
            Text("")
                .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
            Text(provider.displayName)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Action

extension ModelSelectorView {
    /// 选择模型并保存到当前对话
    /// - Parameters:
    ///   - providerId: 供应商 ID
    ///   - model: 模型名称
    private func selectModel(providerId: String, model: String) {
        llmVM.isAutoMode = false
        llmVM.selectedProviderId = providerId
        llmVM.currentModel = model

        // 直接保存到当前对话的模型偏好
        conversationVM.saveModelPreference(providerId: providerId, model: model)

        dismiss()
    }
}

// MARK: - Helper

extension ModelSelectorView {
    /// 检查模型是否为当前选中状态
    private func isSelected(providerId: String, model: String) -> Bool {
        llmVM.selectedProviderId == providerId && llmVM.currentModel == model
    }

    /// 在后台线程加载所有统计数据，避免阻塞 UI
    private func loadAllStats() async {
        isStatsLoaded = false

        let modelContainer = chatHistoryVM.chatHistoryService.getModelContainer()
        let snapshot = await ModelSelectorStatsService.loadSnapshot(
            modelContainer: modelContainer,
            providers: llmVM.allProviders
        )

        guard !Task.isCancelled else { return }

        detailedStats = snapshot.detailedStats
        frequentModels = snapshot.frequentModels
        fastModels = snapshot.fastModels
        isStatsLoaded = true

        if Self.verbose {
            if ChatInputPlugin.verbose {
                            ChatInputPlugin.logger.info("\(Self.t)📊 加载到 \(detailedStats.count) 个模型的性能统计")
            }
            if ChatInputPlugin.verbose {
                            ChatInputPlugin.logger.info("\(Self.t)📊 加载到 \(frequentModels.count) 个常用模型")
            }
            if ChatInputPlugin.verbose {
                            ChatInputPlugin.logger.info("\(Self.t)⚡️ 加载到 \(fastModels.count) 个较快模型")
            }
        }
    }

    /// 加载指定供应商的模型详情（含系列），用于按系列展示
    /// 并行请求所有供应商，避免串行等待
    /// - Parameter providerIds: 需要加载模型详情的供应商 ID 列表
    private func loadLocalModelInfos(providerIds: [String]) async {
        isLoadingLocalModels = true
        localModelInfosByProvider = await ModelSelectorLocalModelService.loadModelInfos(
            providerIds: providerIds,
            llmVM: llmVM
        )
        isLoadingLocalModels = false
    }

    /// 查找指定供应商和模型的详细性能统计
    /// - Parameters:
    ///   - providerId: 供应商 ID
    ///   - modelName: 模型名称
    /// - Returns: 详细性能统计数据，如果不存在则返回 nil
    private func findDetailedStat(providerId: String, modelName: String) -> ModelPerformanceStats? {
        let key = "\(providerId)|\(modelName)"
        return detailedStats[key]
    }

}

// MARK: - Preview

#Preview("ModelSelector") {
    ModelSelectorView()
        .inRootView()
}
