import AppKit
import MagicKit
import LLMKit
import SwiftData
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

    @EnvironmentObject var llmVM: AppLLMVM
    @EnvironmentObject var chatHistoryVM: AppChatHistoryVM

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
                selectedTab: $selectedTab
            )
            .frame(width: 240)
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
                    case .all:
                        providerList(
                            providers: filteredProviders(from: llmVM.allProviders),
                            emptyMessage: String(localized: "No Providers", table: "AgentChat")
                        )
                    case .provider(let providerId):
                        singleProviderList(providerId: providerId)
                    }
                }
                .listStyle(.sidebar)
            }
        }
        .frame(width: 520, height: 800)
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
            default:
                break
            }
        }
    }

    // MARK: - Single Provider List

    /// 单个供应商的模型列表
    @ViewBuilder
    private func singleProviderList(providerId: String) -> some View {
        if let provider = llmVM.allProviders.first(where: { $0.id == providerId }),
           hasVisibleModels(provider: provider) {
            List {
                Section(header: sectionHeader(for: provider)) {
                    modelSectionContent(for: provider)
                }
            }
        } else {
            ContentUnavailableView {
                Label(String(localized: "No Matching Models", table: "AgentChat"), systemImage: "magnifyingglass")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                        modelSectionContent(for: provider)
                    }
                }
            } else {
                ContentUnavailableView {
                    Label(String(localized: "No Matching Models", table: "AgentChat"), systemImage: "magnifyingglass")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            ContentUnavailableView {
                Label(String(localized: "No Provider Selected", table: "AgentChat"), systemImage: "tray")
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
                Label(String(localized: "No Frequent Models", table: "AgentChat"), systemImage: "clock.arrow.circlepath")
            } description: {
                Text(String(localized: "No Frequent Models Description", table: "AgentChat"))
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
        let filteredEntries = filteredFastModels()
        if filteredEntries.isEmpty {
            ContentUnavailableView {
                Label(String(localized: "No Fast Models", table: "AgentChat"), systemImage: "bolt.fill")
            } description: {
                Text(String(localized: "No Fast Models Description", table: "AgentChat"))
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
            ContentUnavailableView {
                Label(emptyMessage, systemImage: "tray")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            let filteredInfos = infos.filter {
                matchesSearch(provider: provider, model: $0.id, displayName: $0.displayName, series: $0.series)
            }
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

private struct ModelSelectorStatsSnapshot: Sendable {
    let detailedStats: [String: ModelPerformanceStats]
    let frequentModels: [FrequentModelEntry]
    let fastModels: [FastModelEntry]
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
    /// 选择模型并保存到项目配置
    /// - Parameters:
    ///   - providerId: 供应商 ID
    ///   - model: 模型名称
    private func selectModel(providerId: String, model: String) {
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
        isStatsLoaded = false

        let modelContainer = chatHistoryVM.chatHistoryService.getModelContainer()
        let providers = llmVM.allProviders

        let snapshot = await Task.detached(priority: .userInitiated) {
            Self.buildStatsSnapshot(modelContainer: modelContainer, providers: providers)
        }.value

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

    nonisolated private static func buildStatsSnapshot(
        modelContainer: ModelContainer,
        providers: [LLMProviderInfo]
    ) -> ModelSelectorStatsSnapshot {
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<ChatMessageEntity>(
            predicate: #Predicate { msg in
                msg.metrics != nil && msg.providerId != nil && msg.modelName != nil
            }
        )

        guard let messageEntities = try? context.fetch(descriptor) else {
            AppLogger.core.error("\(Self.t)❌ 获取模型统计消息失败")
            return ModelSelectorStatsSnapshot(detailedStats: [:], frequentModels: [], fastModels: [])
        }

        var detailedStats: [String: ModelPerformanceStats] = [:]

        for entity in messageEntities {
            guard let providerId = entity.providerId,
                  let modelName = entity.modelName,
                  let metrics = entity.metrics,
                  let latency = metrics.latency else {
                continue
            }

            let key = "\(providerId)|\(modelName)"
            var stats = detailedStats[key] ?? ModelPerformanceStats(
                providerId: providerId,
                modelName: modelName,
                sampleCount: 0,
                totalLatency: 0,
                totalTTFT: 0,
                totalInputTokens: 0,
                totalOutputTokens: 0
            )

            stats.sampleCount += 1
            stats.totalLatency += latency

            if let ttft = metrics.timeToFirstToken {
                stats.totalTTFT += ttft
                stats.ttftCount += 1
            }

            if let inputTokens = metrics.inputTokens {
                stats.totalInputTokens += inputTokens
                stats.inputTokenCount += 1
            }

            if let outputTokens = metrics.outputTokens,
               let streamingDuration = metrics.streamingDuration {
                stats.totalOutputTokens += outputTokens
                stats.outputTokenCount += 1
                stats.totalStreamingDuration += streamingDuration
                stats.streamingDurationCount += 1
            }

            detailedStats[key] = stats
        }

        let providerMap = Dictionary(uniqueKeysWithValues: providers.map { ($0.id, $0) })

        let frequentModels = detailedStats.values
            .filter { stat in
                guard let provider = providerMap[stat.providerId] else { return false }
                return provider.availableModels.contains(stat.modelName)
            }
            .map { stat -> FrequentModelEntry in
                let provider = providerMap[stat.providerId]
                return FrequentModelEntry(
                    id: "\(stat.providerId)|\(stat.modelName)",
                    providerId: stat.providerId,
                    providerDisplayName: provider?.displayName ?? stat.providerId,
                    modelName: stat.modelName,
                    useCount: stat.sampleCount,
                    lastUsedAt: Date()
                )
            }
            .sorted { $0.useCount > $1.useCount }

        let fastModels = detailedStats.values
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

        return ModelSelectorStatsSnapshot(
            detailedStats: detailedStats,
            frequentModels: Array(frequentModels.prefix(10)),
            fastModels: Array(fastModels.prefix(10))
        )
    }

    /// 加载指定供应商的模型详情（含系列），用于按系列展示
    /// 并行请求所有供应商，避免串行等待
    /// - Parameter providerIds: 需要加载模型详情的供应商 ID 列表
    private func loadLocalModelInfos(providerIds: [String]) async {
        isLoadingLocalModels = true

        let providers: [(String, any SuperLocalLLMProvider)] = providerIds.compactMap { id in
            guard let provider = llmVM.createProvider(id: id) as? any SuperLocalLLMProvider else { return nil }
            return (id, provider)
        }

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
        if provider.isLocal {
            return (nil, nil)
        }

        guard let providerType = llmVM.providerType(forId: provider.id),
              let caps = providerType.modelCapabilities[model] else {
            if ChatInputPlugin.verbose {
                            ChatInputPlugin.logger.error("\(Self.t) 远程模型缺少能力声明: provider=\(provider.id), model=\(model)")
            }
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
