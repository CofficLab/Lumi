import AppKit
import MagicKit
import SwiftUI

/// 模型选择器 Tab 类型
enum ModelSelectorTab: String, CaseIterable {
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

    /// 当前选中的 Tab，默认显示当前供应商
    @State private var selectedTab: ModelSelectorTab = .current

    /// 常用模型列表（跨供应商，按使用频率排序）
    @State private var frequentModels: [FrequentModelEntry] = []

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
        VStack(spacing: 0) {
            // Header: Tab + Close
            HStack(spacing: 12) {
                Picker("", selection: $selectedTab) {
                    ForEach(ModelSelectorTab.allCases, id: \.self) { tab in
                        Text(tab.displayTitle).tag(tab)
                    }
                }
                .pickerStyle(.segmented)

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AppUI.Color.semantic.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // List of Providers and Models
            Group {
                switch selectedTab {
                case .current:
                    currentProviderList
                case .frequent:
                    frequentModelsList
                case .local:
                    providerList(providers: localProviders, emptyMessage: String(localized: "No Local Providers", table: "AgentInput"))
                case .remote:
                    providerList(providers: remoteProviders, emptyMessage: String(localized: "No Remote Providers", table: "AgentInput"))
                }
            }
            .listStyle(.sidebar)
        }
        .frame(width: 350, height: 400)
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
            } else if selectedTab == .local {
                await loadLocalModelInfos(providerIds: localProviders.map(\.id))
            }
        }
    }

    // MARK: - Current Provider List

    /// 当前供应商的模型列表
    @ViewBuilder
    private var currentProviderList: some View {
        if let provider = currentProvider {
            List {
                Section(header: sectionHeader(for: provider)) {
                    if provider.isLocal, let infos = localModelInfosByProvider[provider.id], !infos.isEmpty {
                        let fallbackSeries = "其他"
                        let grouped = Dictionary(grouping: infos) { $0.series ?? fallbackSeries }
                        ForEach(grouped.keys.sorted(), id: \.self) { seriesName in
                            Section(header: Text(seriesName).font(AppUI.Typography.subheadline).foregroundColor(AppUI.Color.semantic.textSecondary)) {
                                ForEach(grouped[seriesName] ?? [], id: \.id) { info in
                                    modelRow(provider: provider, model: info.id, displayName: info.displayName)
                                }
                            }
                        }
                    } else {
                        ForEach(provider.availableModels, id: \.self) { model in
                            modelRow(provider: provider, model: model)
                        }
                    }
                }
            }
        } else {
            ContentUnavailableView {
                Label(String(localized: "No Provider Selected", table: "AgentInput"), systemImage: "tray")
            }
        }
    }

    // MARK: - Frequent Models List

    /// 常用模型列表（跨供应商，按使用频率排序）
    @ViewBuilder
    private var frequentModelsList: some View {
        if frequentModels.isEmpty {
            ContentUnavailableView {
                Label(String(localized: "No Frequent Models", table: "AgentInput"), systemImage: "clock.arrow.circlepath")
            } description: {
                Text(String(localized: "No Frequent Models Description", table: "AgentInput"))
            }
        } else {
            List {
                ForEach(frequentModels) { entry in
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

                        if isSelected(providerId: entry.providerId, model: entry.modelName) {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
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
        } else {
            List {
                ForEach(providers) { provider in
                    Section(header: sectionHeader(for: provider)) {
                        if provider.isLocal, let infos = localModelInfosByProvider[provider.id], !infos.isEmpty {
                            let fallbackSeries = "其他"
                            let grouped = Dictionary(grouping: infos) { $0.series ?? fallbackSeries }
                            ForEach(grouped.keys.sorted(), id: \.self) { seriesName in
                                Section(header: Text(seriesName).font(AppUI.Typography.subheadline).foregroundColor(AppUI.Color.semantic.textSecondary)) {
                                    ForEach(grouped[seriesName] ?? [], id: \.id) { info in
                                        modelRow(provider: provider, model: info.id, displayName: info.displayName)
                                    }
                                }
                            }
                        } else {
                            ForEach(provider.availableModels, id: \.self) { model in
                                modelRow(provider: provider, model: model)
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
    @ViewBuilder
    private func modelRow(provider: LLMProviderInfo, model: String, displayName: String? = nil) -> some View {
        Button(action: {
            selectModel(providerId: provider.id, model: model)
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
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
                        if isSelected(providerId: provider.id, model: model) {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
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
                    .fill(isSelected(providerId: provider.id, model: model) ? Color.accentColor.opacity(0.15) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected(providerId: provider.id, model: model) ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if hovering && !isSelected(providerId: provider.id, model: model) {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
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
