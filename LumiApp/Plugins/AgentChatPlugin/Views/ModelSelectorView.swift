import AppKit
import MagicKit
import SwiftUI

/// 模型选择器视图
/// 允许用户从所有已注册的供应商和模型中选择
struct ModelSelectorView: View, SuperLog {
    /// 日志标识 emoji
    nonisolated static let emoji = "🌐"
    /// 是否输出详细日志
    nonisolated static let verbose: Bool = false
    /// 环境对象：用于关闭当前视图
    @Environment(\.dismiss) private var dismiss

    @EnvironmentObject var llmVM: LLMVM
    @EnvironmentObject var chatHistoryVM: ChatHistoryVM

    /// 模型性能统计
    @State private var detailedStats: [String: ModelPerformanceStats] = [:]

    /// 当前选中的 Tab，默认显示全部
    @State private var selectedTab: ModelSelectorTab = .all

    /// 当前 hover 的 Tab
    @State private var hoveringTab: ModelSelectorTab? = nil

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

    private var localProviders: [LLMProviderInfo] {
        llmVM.allProviders.filter(\.isLocal)
    }

    private var remoteProviders: [LLMProviderInfo] {
        llmVM.allProviders.filter { !$0.isLocal }
    }

    var body: some View {
        HStack(spacing: 0) {
            ModelSelectorTabSidebar(
                selectedTab: $selectedTab,
                hoveringTab: $hoveringTab
            )
            .frame(width: 180)
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
                    case .all:
                        providerList(
                            providers: filteredProviders(from: llmVM.allProviders),
                            emptyMessage: String(localized: "No Providers", table: "AgentInput")
                        )
                    case .current:
                        currentProviderList
                    case .frequent:
                        frequentModelsList
                    case .fast:
                        fastModelsList
                    case .local:
                        providerList(
                            providers: filteredProviders(from: localProviders),
                            emptyMessage: String(localized: "No Local Providers", table: "AgentInput")
                        )
                    case .remote:
                        providerList(
                            providers: filteredProviders(from: remoteProviders),
                            emptyMessage: String(localized: "No Remote Providers", table: "AgentInput")
                        )
                    }
                }
                .listStyle(.sidebar)
            }
        }
        .frame(width: 520, height: 400)
        .background(AppUI.Material.glass)
        .task {
            // 将同步的数据库查询放到后台线程，避免阻塞 UI
            await loadAllStats()
        }
        .task(id: selectedTab) {
            if selectedTab == .current {
                if currentProvider?.isLocal == true {
                    await loadLocalModelInfos(providerIds: [llmVM.selectedProviderId])
                }
            } else if selectedTab == .local || selectedTab == .all {
                await loadLocalModelInfos(providerIds: localProviders.map(\.id))
            }
        }
    }

    // MARK: - Current Provider List

    /// 当前供应商的模型列表
    @ViewBuilder
    private var currentProviderList: some View {
        if let provider = currentProvider {
            if hasVisibleModels(provider: provider) {
                List {
                    Section(header: sectionHeader(for: provider)) {
                        if provider.isLocal, let infos = localModelInfosByProvider[provider.id], !infos.isEmpty {
                            let filteredInfos = infos.filter {
                                matchesSearch(provider: provider, model: $0.id, displayName: $0.displayName, series: $0.series)
                            }
                            let fallbackSeries = "其他"
                            let grouped = Dictionary(grouping: filteredInfos) { $0.series ?? fallbackSeries }
                            ForEach(grouped.keys.sorted(), id: \.self) { seriesName in
                                Section(header: Text(seriesName).font(AppUI.Typography.subheadline).foregroundColor(AppUI.Color.semantic.textSecondary)) {
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
                            let filteredModels = provider.availableModels.filter {
                                matchesSearch(provider: provider, model: $0)
                            }
                            ForEach(filteredModels, id: \.self) { model in
                                let caps = capabilityValues(provider: provider, model: model)
                                modelRow(
                                    provider: provider,
                                    model: model,
                                    supportsVision: caps.supportsVision,
                                    supportsTools: caps.supportsTools
                                )
                            }
                        }
                    }
                }
            } else {
                ContentUnavailableView {
                    Label(String(localized: "No Matching Models", table: "AgentInput"), systemImage: "magnifyingglass")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            ContentUnavailableView {
                Label(String(localized: "No Provider Selected", table: "AgentInput"), systemImage: "tray")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Frequent Models List

    /// 常用模型列表（跨供应商，按使用频率排序）
    @ViewBuilder
    private var frequentModelsList: some View {
        let filteredEntries = filteredFrequentModels()
        if filteredEntries.isEmpty {
            ContentUnavailableView {
                Label(String(localized: "No Frequent Models", table: "AgentInput"), systemImage: "clock.arrow.circlepath")
            } description: {
                Text(String(localized: "No Frequent Models Description", table: "AgentInput"))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        FrequentModelRow(
            entry: entry,
            isSelected: isSelected(providerId: entry.providerId, model: entry.modelName),
            stat: findDetailedStat(providerId: entry.providerId, modelName: entry.modelName)
        ) {
            selectModel(providerId: entry.providerId, model: entry.modelName)
        }
    }

    // MARK: - Fast Models List

    /// TPS 较快模型列表（跨供应商，按 TPS 降序，最多 10 个）
    @ViewBuilder
    private var fastModelsList: some View {
        let filteredEntries = filteredFastModels()
        if filteredEntries.isEmpty {
            ContentUnavailableView {
                Label(String(localized: "No Fast Models", table: "AgentInput"), systemImage: "bolt.fill")
            } description: {
                Text(String(localized: "No Fast Models Description", table: "AgentInput"))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        FastModelRow(
            entry: entry,
            isSelected: isSelected(providerId: entry.providerId, model: entry.modelName),
            stat: findDetailedStat(providerId: entry.providerId, modelName: entry.modelName)
        ) {
            selectModel(providerId: entry.providerId, model: entry.modelName)
        }
    }

    /// 供应商与模型列表（共用结构）；本地供应商有缓存时按系列分组展示
    @ViewBuilder
    private func providerList(providers: [LLMProviderInfo], emptyMessage: String) -> some View {
        if providers.isEmpty {
            ContentUnavailableView {
                Label(emptyMessage, systemImage: "tray")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                ForEach(providers) { provider in
                    Section(header: sectionHeader(for: provider)) {
                        if provider.isLocal, let infos = localModelInfosByProvider[provider.id], !infos.isEmpty {
                            let filteredInfos = infos.filter {
                                matchesSearch(provider: provider, model: $0.id, displayName: $0.displayName, series: $0.series)
                            }
                            let fallbackSeries = "其他"
                            let grouped = Dictionary(grouping: filteredInfos) { $0.series ?? fallbackSeries }
                            ForEach(grouped.keys.sorted(), id: \.self) { seriesName in
                                Section(header: Text(seriesName).font(AppUI.Typography.subheadline).foregroundColor(AppUI.Color.semantic.textSecondary)) {
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
                            let filteredModels = provider.availableModels.filter {
                                matchesSearch(provider: provider, model: $0)
                            }
                            ForEach(filteredModels, id: \.self) { model in
                                let caps = capabilityValues(provider: provider, model: model)
                                modelRow(
                                    provider: provider,
                                    model: model,
                                    supportsVision: caps.supportsVision,
                                    supportsTools: caps.supportsTools
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    /// 单行模型
    private func modelRow(
        provider: LLMProviderInfo,
        model: String,
        displayName: String? = nil,
        supportsVision: Bool? = nil,
        supportsTools: Bool? = nil
    ) -> some View {
        let hoverKey = "\(provider.id)|\(model)"
        return ModelSelectorModelRow(
            provider: provider,
            model: model,
            displayName: displayName,
            supportsVision: supportsVision,
            supportsTools: supportsTools,
            isSelected: isSelected(providerId: provider.id, model: model),
            isHovering: hoveringModelId == hoverKey,
            stat: findDetailedStat(providerId: provider.id, modelName: model),
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
                .foregroundColor(AppUI.Color.semantic.textSecondary)
            Text(provider.displayName)
                .font(AppUI.Typography.bodyEmphasized)
                .foregroundColor(AppUI.Color.semantic.textPrimary)
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Action

extension ModelSelectorView {
    /// 选择模型并保存到项目配置
    /// - Parameters:
    ///   - providerId: 供应商 ID
    ///   - model: 模型名称
    private func selectModel(providerId: String, model: String) {
        // 更新内存中的供应商和模型配置
        llmVM.selectedProviderId = providerId
        llmVM.currentModel = model

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
        // 先加载详细统计（这是最耗时的操作，涉及大量 SwiftData 查询）
        loadLatencyStats()
        // 基于已加载的统计数据构建常用模型和快模型列表
        loadFrequentModels()
        loadFastModels()
        isStatsLoaded = true
    }

    /// 加载性能统计数据（仅内部使用，已移至 loadAllStats）
    private func loadLatencyStats() {
        detailedStats = chatHistoryVM.getModelDetailedStats()
        if Self.verbose {
            AgentChatPlugin.logger.info("\(Self.t)📊 加载到 \(detailedStats.count) 个模型的性能统计")
        }
    }

    /// 加载常用模型列表
    /// 从聊天历史中统计每个 provider+model 的使用次数，按次数降序排列，最多显示 10 个
    private func loadFrequentModels() {
        let stats = chatHistoryVM.getModelLatencyStats()
        let providers = llmVM.allProviders
        let providerMap = Dictionary(uniqueKeysWithValues: providers.map { ($0.id, $0) })

        // 按 (providerId, modelName) 聚合使用次数
        var usageDict: [String: (providerId: String, modelName: String, count: Int)] = [:]
        for stat in stats {
            let key = "\(stat.providerId)|\(stat.modelName)"
            if var existing = usageDict[key] {
                existing.count += stat.sampleCount
                usageDict[key] = existing
            } else {
                usageDict[key] = (providerId: stat.providerId, modelName: stat.modelName, count: stat.sampleCount)
            }
        }

        // 只保留当前已注册供应商中仍然可用的模型
        let entries = usageDict.values
            .filter { entry in
                guard let provider = providerMap[entry.providerId] else { return false }
                return provider.availableModels.contains(entry.modelName)
            }
            .map { entry -> FrequentModelEntry in
                let provider = providerMap[entry.providerId]
                return FrequentModelEntry(
                    id: "\(entry.providerId)|\(entry.modelName)",
                    providerId: entry.providerId,
                    providerDisplayName: provider?.displayName ?? entry.providerId,
                    modelName: entry.modelName,
                    useCount: entry.count,
                    lastUsedAt: Date()  // 简化：不追踪精确的最后使用时间
                )
            }
            .sorted { $0.useCount > $1.useCount }

        frequentModels = Array(entries.prefix(10))

        if Self.verbose {
            AgentChatPlugin.logger.info("\(Self.t)📊 加载到 \(frequentModels.count) 个常用模型")
        }
    }

    /// 加载指定供应商的模型详情（含系列），用于按系列展示
    /// 并行请求所有供应商，避免串行等待
    /// - Parameter providerIds: 需要加载模型详情的供应商 ID 列表
    private func loadLocalModelInfos(providerIds: [String]) async {
        isLoadingLocalModels = true

        // 在主线程提前创建好所有 provider（createProvider 需要 MainActor）
        let providers: [(String, any SuperLocalLLMProvider)] = providerIds.compactMap { id in
            guard let provider = llmVM.createProvider(id: id) as? any SuperLocalLLMProvider else { return nil }
            return (id, provider)
        }

        // 并行请求所有本地供应商的模型列表
        let results = await withTaskGroup(of: (String, [LocalModelInfo]).self) { group in
            for (id, provider) in providers {
                group.addTask {
                    let infos = await provider.getAvailableModels()
                    return (id, infos)
                }
            }

            var combined: [String: [LocalModelInfo]] = [:]
            for await (id, infos) in group {
                if !infos.isEmpty {
                    combined[id] = infos
                }
            }
            return combined
        }

        localModelInfosByProvider = results
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

    /// 读取模型能力声明（用于远程模型 badge 展示）
    /// - Parameters:
    ///   - provider: 供应商信息
    ///   - model: 模型 ID
    /// - Returns: (supportsVision, supportsTools)
    private func capabilityValues(provider: LLMProviderInfo, model: String) -> (supportsVision: Bool?, supportsTools: Bool?) {
        // 本地模型优先使用 LocalModelInfo；若未提供则不显示
        if provider.isLocal {
            return (nil, nil)
        }

        guard let caps = provider.modelCapabilities[model] else {
            AgentChatPlugin.logger.error("\(Self.t) 远程模型缺少能力声明: provider=\(provider.id), model=\(model)")
            return (nil, nil)
        }

        return (caps.supportsVision, caps.supportsTools)
    }

    /// 根据搜索词过滤供应商（保留至少有一个可见模型的供应商）
    private func filteredProviders(from providers: [LLMProviderInfo]) -> [LLMProviderInfo] {
        let keyword = normalizedSearchText
        guard !keyword.isEmpty else { return providers }

        return providers.filter { provider in
            hasVisibleModels(provider: provider)
        }
    }

    /// 判断供应商在当前搜索词下是否还有可见模型
    private func hasVisibleModels(provider: LLMProviderInfo) -> Bool {
        if matchesSearch(provider: provider, model: "") {
            return true
        }

        if provider.isLocal, let infos = localModelInfosByProvider[provider.id], !infos.isEmpty {
            return infos.contains { info in
                matchesSearch(provider: provider, model: info.id, displayName: info.displayName, series: info.series)
            }
        }

        return provider.availableModels.contains { model in
            matchesSearch(provider: provider, model: model)
        }
    }

    /// 根据搜索词过滤常用模型
    private func filteredFrequentModels() -> [FrequentModelEntry] {
        let keyword = normalizedSearchText
        guard !keyword.isEmpty else { return frequentModels }

        return frequentModels.filter { entry in
            entry.modelName.localizedCaseInsensitiveContains(keyword)
                || entry.providerDisplayName.localizedCaseInsensitiveContains(keyword)
                || entry.providerId.localizedCaseInsensitiveContains(keyword)
        }
    }

    /// 加载 TPS 较快模型列表（跨供应商，按 TPS 降序，最多 10 个）
    private func loadFastModels() {
        let providers = llmVM.allProviders
        let providerMap = Dictionary(uniqueKeysWithValues: providers.map { ($0.id, $0) })

        let entries = detailedStats.values
            .filter { stat in
                stat.avgTPS > 0 && stat.sampleCount > 0
            }
            .filter { stat in
                guard let provider = providerMap[stat.providerId] else { return false }
                return provider.availableModels.contains(stat.modelName)
            }
            .map { stat -> FastModelEntry in
                let provider = providerMap[stat.providerId]
                return FastModelEntry(
                    id: "\(stat.providerId)|\(stat.modelName)",
                    providerId: stat.providerId,
                    providerDisplayName: provider?.displayName ?? stat.providerId,
                    modelName: stat.modelName,
                    avgTPS: stat.avgTPS,
                    sampleCount: stat.sampleCount
                )
            }
            .sorted { lhs, rhs in
                if lhs.avgTPS == rhs.avgTPS {
                    return lhs.sampleCount > rhs.sampleCount
                }
                return lhs.avgTPS > rhs.avgTPS
            }

        fastModels = Array(entries.prefix(10))

        if Self.verbose {
            AgentChatPlugin.logger.info("\(Self.t)⚡️ 加载到 \(fastModels.count) 个较快模型")
        }
    }

    /// 根据搜索词过滤 TPS 较快模型
    private func filteredFastModels() -> [FastModelEntry] {
        let keyword = normalizedSearchText
        guard !keyword.isEmpty else { return fastModels }

        return fastModels.filter { entry in
            entry.modelName.localizedCaseInsensitiveContains(keyword)
                || entry.providerDisplayName.localizedCaseInsensitiveContains(keyword)
                || entry.providerId.localizedCaseInsensitiveContains(keyword)
        }
    }

    /// 模型项是否匹配当前搜索词（匹配模型名、展示名、系列、供应商）
    private func matchesSearch(provider: LLMProviderInfo, model: String, displayName: String? = nil, series: String? = nil) -> Bool {
        let keyword = normalizedSearchText
        guard !keyword.isEmpty else { return true }

        return [
            model,
            displayName ?? "",
            series ?? "",
            provider.displayName,
            provider.id,
        ]
        .contains { $0.localizedCaseInsensitiveContains(keyword) }
    }

    /// 规范化搜索词
    private var normalizedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Preview

#Preview("ModelSelector") {
    ModelSelectorView()
        .inRootView()
}
