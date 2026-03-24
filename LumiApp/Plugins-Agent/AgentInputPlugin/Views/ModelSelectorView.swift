import AppKit
import MagicKit
import SwiftUI

/// 模型选择器视图
/// 允许用户从所有已注册的供应商和模型中选择
struct ModelSelectorView: View, SuperLog {
    /// 日志标识 emoji
    nonisolated static let emoji = "🌐"
    /// 是否输出详细日志
    nonisolated static let verbose = false

    /// 环境对象：用于关闭当前视图
    @Environment(\.dismiss) private var dismiss

    @EnvironmentObject var llmVM: LLMVM
    @EnvironmentObject var chatHistoryVM: ChatHistoryVM

    /// 模型性能统计
    @State private var detailedStats: [String: ModelPerformanceStats] = [:]

    /// 当前选中的 Tab：0 本地，1 远程
    @AppStorage("ModelSelectorView.selectedTab") private var selectedTab = 0

    /// 本地供应商的模型详情（按 providerId -> [LocalModelInfo]），用于按系列展示
    @State private var localModelInfosByProvider: [String: [LocalModelInfo]] = [:]

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
                    Text(String(localized: "Local Providers", table: "AgentInput")).tag(0)
                    Text(String(localized: "Remote Providers", table: "AgentInput")).tag(1)
                }
                .pickerStyle(.segmented)

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // List of Providers and Models
            Group {
                if selectedTab == 0 {
                    providerList(providers: localProviders, emptyMessage: String(localized: "No Local Providers", table: "AgentInput"))
                } else {
                    providerList(providers: remoteProviders, emptyMessage: String(localized: "No Remote Providers", table: "AgentInput"))
                }
            }
            .listStyle(.sidebar)
        }
        .frame(width: 350, height: 400)
        .background(DesignTokens.Material.glass)
        .task {
            loadLatencyStats()
        }
        .task(id: selectedTab) {
            if selectedTab == 0 {
                await loadLocalModelInfos()
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
                                Section(header: Text(seriesName).font(.subheadline).foregroundColor(.secondary)) {
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

    /// 单行模型：名称、性能条、选中态
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
                VStack(alignment: .leading) {
                    Text(displayName ?? model)
                        .font(.body)
                    if let stat = findDetailedStat(providerId: provider.id, modelName: model), stat.avgTTFT > 0 {
                        ModelLatencyProgressBar(
                            ttft: stat.avgTTFT,
                            totalLatency: stat.avgLatency,
                            sampleCount: stat.sampleCount
                        )
                    }
                }
                Spacer()
                if isSelected(providerId: provider.id, model: model) {
                    Image(systemName: "checkmark")
                        .foregroundColor(.accentColor)
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
            Image(systemName: provider.iconName)
                .foregroundColor(.secondary)
            Text(provider.displayName)
                .font(.headline)
                .foregroundColor(.primary)
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

    /// 加载本地供应商的模型详情（含系列），用于按系列展示
    private func loadLocalModelInfos() async {
        let localIds = llmVM.allProviders.filter(\.isLocal).map(\.id)
        var result: [String: [LocalModelInfo]] = [:]
        for id in localIds {
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
}

// MARK: - Model Latency Progress Bar

/// 模型耗时进度条组件
struct ModelLatencyProgressBar: View {
    let ttft: Double
    let totalLatency: Double
    let sampleCount: Int

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

                if sampleCount > 1 {
                    Text("(\(sampleCount))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
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

    /// 帮助文本
    private var helpText: String {
        let ttftPercent = String(format: "%.1f", ttftRatio * 100)
        let responsePercent = String(format: "%.1f", (1 - ttftRatio) * 100)
        return """
        ⚡ 首个 Token 延迟 (TTFT): \(formatTTFT(ttft)) (\(ttftPercent)%)
        🕐 响应时间: \(formatLatency(totalLatency)) (\(responsePercent)%)

        TTFT 表示从发送请求到收到第一个 token 的时间
        响应时间表示从第一个 token 到响应完成的时间
        """
    }
}

// MARK: - Preview

#Preview("ModelSelector") {
    ModelSelectorView()
        .inRootView()
}
