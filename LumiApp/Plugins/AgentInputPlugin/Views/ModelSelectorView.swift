import AppKit
import MagicKit
import SwiftUI

/// 模型选择器 Tab 类型
enum ModelSelectorTab: String, CaseIterable {
    /// 全部供应商与模型
    case all
    /// 当前供应商
    case current
    /// 常用模型（跨供应商）
    case frequent
    /// 本地供应商
    case local
    /// 远程供应商
    case remote

    /// Tab 显示标题
    var displayTitle: String {
        switch self {
        case .all:
            return String(localized: "All", table: "AgentInput")
        case .current:
            return String(localized: "Current Provider", table: "AgentInput")
        case .frequent:
            return String(localized: "Frequent", table: "AgentInput")
        case .local:
            return String(localized: "Local Providers", table: "AgentInput")
        case .remote:
            return String(localized: "Remote Providers", table: "AgentInput")
        }
    }
}

/// 常用模型条目，用于跨供应商展示最近常用的模型
struct FrequentModelEntry: Identifiable {
    /// 唯一标识（providerId + modelName 组合）
    let id: String
    /// 供应商 ID
    let providerId: String
    /// 供应商显示名称
    let providerDisplayName: String
    /// 模型名称
    let modelName: String
    /// 使用次数
    let useCount: Int
    /// 最后使用时间
    let lastUsedAt: Date
}

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

    /// 搜索关键词（用于过滤模型/供应商）
    @State private var searchText: String = ""

    /// 本地供应商的模型详情（按 providerId -> [LocalModelInfo]），用于按系列展示
    @State private var localModelInfosByProvider: [String: [LocalModelInfo]] = [:]

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
            tabSidebar
                .frame(width: 120)
                .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(AppUI.Color.semantic.textSecondary)
                    TextField(String(localized: "Search Models", table: "AgentInput"), text: $searchText)
                        .textFieldStyle(.plain)

                    Spacer()

                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppUI.Color.semantic.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(nsColor: .controlBackgroundColor))

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
            loadLatencyStats()
            loadFrequentModels()
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

    // MARK: - Tab Sidebar

    @ViewBuilder
    private var tabSidebar: some View {
        VStack(spacing: 4) {
            ForEach(ModelSelectorTab.allCases, id: \.self) { tab in
                Button(action: { selectedTab = tab }) {
                    HStack(spacing: 8) {
                        Image(systemName: tabIconName(for: tab))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppUI.Color.semantic.textSecondary)
                            .frame(width: 16, alignment: .center)
                        Text(tab.displayTitle)
                            .font(AppUI.Typography.body)
                            .lineLimit(1)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(tabBackgroundColor(for: tab))
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    hoveringTab = hovering ? tab : nil
                }
            }
            Spacer()
        }
        .padding(8)
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

    /// 常用模型的单行视图，显示模型名、供应商标签和性能信息
    @ViewBuilder
    private func frequentModelRow(entry: FrequentModelEntry) -> some View {
        Button(action: {
            selectModel(providerId: entry.providerId, model: entry.modelName)
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(entry.modelName)
                            .font(AppUI.Typography.body)
                            .lineLimit(1)

                        // 供应商标签
                        Text(entry.providerDisplayName)
                            .font(.caption2)
                            .foregroundColor(AppUI.Color.semantic.textSecondary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(AppUI.Color.semantic.textSecondary.opacity(0.12))
                            )

                        Spacer()

                        // 使用次数
                        Text("\(entry.useCount)")
                            .font(.caption2)
                            .foregroundColor(AppUI.Color.semantic.textSecondary)
                    }
                    if let stat = findDetailedStat(providerId: entry.providerId, modelName: entry.modelName), stat.avgTTFT > 0 {
                        ModelLatencyProgressBar(
                            ttft: stat.avgTTFT,
                            totalLatency: stat.avgLatency,
                            sampleCount: stat.sampleCount,
                            tps: stat.avgTPS
                        )
                    }
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected(providerId: entry.providerId, model: entry.modelName) ? Color.accentColor.opacity(0.15) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected(providerId: entry.providerId, model: entry.modelName) ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if hovering && !isSelected(providerId: entry.providerId, model: entry.modelName) {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
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

    /// 单行模型：名称（左）、上下文大小（右）、性能条、选中态
    /// - Parameters:
    ///   - provider: 供应商信息
    ///   - model: 模型 ID（用于选中/保存）
    ///   - displayName: 可选展示名；本地模型用 displayName，远程用 nil 则显示 model
    ///   - supportsVision: 是否支持视觉输入（可选）
    ///   - supportsTools: 是否支持工具调用（可选）
    @ViewBuilder
    private func modelRow(
        provider: LLMProviderInfo,
        model: String,
        displayName: String? = nil,
        supportsVision: Bool? = nil,
        supportsTools: Bool? = nil
    ) -> some View {
        Button(action: {
            selectModel(providerId: provider.id, model: model)
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(displayName ?? model)
                                    .font(AppUI.Typography.body)
                                    .lineLimit(1)

                                Spacer()
                                if let contextSize = provider.contextWindowSizes[model] {
                                    Text(formatContextSize(contextSize))
                                        .font(.caption2)
                                        .foregroundColor(AppUI.Color.semantic.textSecondary)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(
                                            RoundedRectangle(cornerRadius: 3)
                                                .fill(AppUI.Color.semantic.textSecondary.opacity(0.12))
                                        )
                                }
                            }

                            HStack(spacing: 6) {
                                if let supportsVision {
                                    capabilityBadge(
                                        title: supportsVision
                                            ? String(localized: "Image", table: "AgentInput")
                                            : String(localized: "Text", table: "AgentInput"),
                                        systemImage: supportsVision ? "photo" : "text.bubble"
                                    )
                                }

                                if let supportsTools, supportsTools {
                                    capabilityBadge(
                                        title: String(localized: "Tools", table: "AgentInput"),
                                        systemImage: "wrench.and.screwdriver"
                                    )
                                }
                            }
                        }
                    }
                    if let stat = findDetailedStat(providerId: provider.id, modelName: model), stat.avgTTFT > 0 {
                        ModelLatencyProgressBar(
                            ttft: stat.avgTTFT,
                            totalLatency: stat.avgLatency,
                            sampleCount: stat.sampleCount,
                            tps: stat.avgTPS
                        )
                    }
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(modelRowBackgroundColor(providerId: provider.id, model: model))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected(providerId: provider.id, model: model) ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if hovering {
                hoveringModelId = modelRowHoverId(providerId: provider.id, model: model)
                if !isSelected(providerId: provider.id, model: model) {
                    NSCursor.pointingHand.push()
                }
            } else {
                if hoveringModelId == modelRowHoverId(providerId: provider.id, model: model) {
                    hoveringModelId = nil
                }
                NSCursor.pop()
            }
        }
    }

    @ViewBuilder
    private func capabilityBadge(title: String, systemImage: String) -> some View {
        HStack(spacing: 2) {
            Image(systemName: systemImage)
                .font(.system(size: 8, weight: .medium))
            Text(title)
                .font(.caption2)
        }
        .foregroundColor(AppUI.Color.semantic.textSecondary)
        .padding(.horizontal, 4)
        .padding(.vertical, 1)
        .background(
            RoundedRectangle(cornerRadius: 3)
                .fill(AppUI.Color.semantic.textSecondary.opacity(0.12))
        )
        .help(title)
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
    /// - Parameters:
    ///   - providerId: 供应商 ID
    ///   - model: 模型名称
    /// - Returns: 是否为当前选中的模型
    private func isSelected(providerId: String, model: String) -> Bool {
        return llmVM.selectedProviderId == providerId && llmVM.currentModel == model
    }

    /// 检查模型是否为供应商的默认模型
    /// - Parameters:
    ///   - providerId: 供应商 ID
    ///   - model: 模型名称
    /// - Returns: 是否为默认模型
    private func isDefaultModel(providerId: String, model: String) -> Bool {
        guard let providerType = llmVM.providerType(forId: providerId) else {
            return false
        }
        return model == providerType.defaultModel
    }

    /// 加载性能统计数据
    private func loadLatencyStats() {
        detailedStats = chatHistoryVM.getModelDetailedStats()
        if Self.verbose {
            AgentInputPlugin.logger.info("\(Self.t)📊 加载到 \(detailedStats.count) 个模型的性能统计")
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
            AgentInputPlugin.logger.info("\(Self.t)📊 加载到 \(frequentModels.count) 个常用模型")
        }
    }

    /// 加载指定供应商的模型详情（含系列），用于按系列展示
    /// - Parameter providerIds: 需要加载模型详情的供应商 ID 列表
    private func loadLocalModelInfos(providerIds: [String]) async {
        var result: [String: [LocalModelInfo]] = [:]
        for id in providerIds {
            guard let provider = llmVM.createProvider(id: id) as? any SuperLocalLLMProvider else { continue }
            let infos = await provider.getAvailableModels()
            result[id] = infos
        }
        localModelInfosByProvider = result
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
            AgentInputPlugin.logger.error("\(Self.t) 远程模型缺少能力声明: provider=\(provider.id), model=\(model)")
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

    /// Tab 图标
    private func tabIconName(for tab: ModelSelectorTab) -> String {
        switch tab {
        case .all:
            return "globe"
        case .current:
            return "scope"
        case .frequent:
            return "clock.arrow.circlepath"
        case .local:
            return "laptopcomputer"
        case .remote:
            return "cloud"
        }
    }

    /// Tab 背景色
    private func tabBackgroundColor(for tab: ModelSelectorTab) -> Color {
        if selectedTab == tab {
            return Color.accentColor.opacity(0.15)
        }
        if hoveringTab == tab {
            return Color.accentColor.opacity(0.08)
        }
        return Color.clear
    }

    /// 模型行 hover key
    private func modelRowHoverId(providerId: String, model: String) -> String {
        "\(providerId)|\(model)"
    }

    /// 模型行背景色
    private func modelRowBackgroundColor(providerId: String, model: String) -> Color {
        if isSelected(providerId: providerId, model: model) {
            return Color.accentColor.opacity(0.15)
        }
        if hoveringModelId == modelRowHoverId(providerId: providerId, model: model) {
            return Color.accentColor.opacity(0.08)
        }
        return Color.clear
    }

    /// 格式化上下文窗口大小为人类可读字符串
    /// - Parameter tokens: Token 数量
    /// - Returns: 格式化后的字符串，如 "200K"、"1M"、"8K"
    private func formatContextSize(_ tokens: Int) -> String {
        if tokens >= 1_000_000 {
            let value = Double(tokens) / 1_000_000.0
            return value == floor(value) ? "\(Int(value))M" : String(format: "%.1fM", value)
        } else if tokens >= 1_000 {
            let value = Double(tokens) / 1_000.0
            return value == floor(value) ? "\(Int(value))K" : String(format: "%.0fK", value)
        } else {
            return "\(tokens)"
        }
    }
}

// MARK: - Model Latency Progress Bar

/// 模型耗时进度条组件
struct ModelLatencyProgressBar: View {
    let ttft: Double
    let totalLatency: Double
    let sampleCount: Int
    let tps: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // 进度条
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    // TTFT 部分（橙色）
                    Rectangle()
                        .fill(Color.orange)
                        .frame(width: geometry.size.width * ttftRatio)

                    // 响应时间部分（蓝色）
                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: geometry.size.width * (1 - ttftRatio))
                }
            }
            .frame(width: 80, height: 3)
            .clipShape(RoundedRectangle(cornerRadius: 1.5))

            // 时间信息（一行显示）
            HStack(spacing: 6) {
                HStack(spacing: 1) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 6, weight: .medium))
                    Text(formatTTFT(ttft))
                        .font(.caption2)
                }
                .foregroundColor(.orange)

                HStack(spacing: 1) {
                    Image(systemName: "clock")
                        .font(.system(size: 6, weight: .medium))
                    Text(formatLatency(totalLatency))
                        .font(.caption2)
                }
                .foregroundColor(.blue)

                // TPS 显示
                if tps > 0 {
                    HStack(spacing: 1) {
                        Image(systemName: "speedometer")
                            .font(.system(size: 6, weight: .medium))
                        Text(formatTPS(tps))
                            .font(.caption2)
                    }
                    .foregroundColor(.green)
                }

                if sampleCount > 1 {
                    Text("(\(sampleCount))")
                        .font(.caption2)
                        .foregroundColor(AppUI.Color.semantic.textSecondary)
                }
            }
        }
        .help(helpText)
    }

    /// TTFT 占总耗时的比例
    private var ttftRatio: Double {
        guard totalLatency > 0 else { return 0 }
        return min(ttft / totalLatency, 1.0)
    }

    /// 格式化 TTFT
    private func formatTTFT(_ ttft: Double) -> String {
        if ttft >= 1000 {
            return String(format: "%.1fs", ttft / 1000.0)
        } else {
            return String(format: "%.0fms", ttft)
        }
    }

    /// 格式化响应时间
    private func formatLatency(_ latency: Double) -> String {
        if latency >= 1000 {
            return String(format: "%.1fs", latency / 1000.0)
        } else {
            return String(format: "%.0fms", latency)
        }
    }

    /// 格式化 TPS
    private func formatTPS(_ tps: Double) -> String {
        if tps >= 100 {
            return String(format: "%.0f t/s", tps)
        } else if tps >= 10 {
            return String(format: "%.1f t/s", tps)
        } else {
            return String(format: "%.2f t/s", tps)
        }
    }

    /// 帮助文本
    private var helpText: String {
        let ttftPercent = String(format: "%.1f", ttftRatio * 100)
        let responsePercent = String(format: "%.1f", (1 - ttftRatio) * 100)
        var text = """
        ⚡ 首个 Token 延迟 (TTFT): \(formatTTFT(ttft)) (\(ttftPercent)%)
        🕐 响应时间: \(formatLatency(totalLatency)) (\(responsePercent)%)
        """

        if tps > 0 {
            text += "\n🚀 生成速度: \(formatTPS(tps))"
        }

        text += """


        TTFT 表示从发送请求到收到第一个 token 的时间
        响应时间表示从第一个 token 到响应完成的时间
        """

        if tps > 0 {
            text += "TPS (Tokens Per Second) 表示每秒生成的 token 数量"
        }

        return text
    }
}

// MARK: - Preview

#Preview("ModelSelector") {
    ModelSelectorView()
        .inRootView()
}
