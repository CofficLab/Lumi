import AppKit
import MagicKit
import OSLog
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

    /// 智能体提供者
    @EnvironmentObject var agentProvider: AgentProvider

    /// 模型性能统计
    @State private var detailedStats: [String: ModelPerformanceStats] = [:]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Select Model")
                    .font(.headline)
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
            List {
                ForEach(agentProvider.registry.allProviders()) { provider in
                    Section(header: sectionHeader(for: provider)) {
                        ForEach(provider.availableModels, id: \.self) { model in
                            Button(action: {
                                selectModel(providerId: provider.id, model: model)
                            }) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(model)
                                            .font(.body)
                                        if isDefaultModel(providerId: provider.id, model: model) {
                                            Text("Default")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        // 显示性能统计
                                        if let stat = findDetailedStat(providerId: provider.id, modelName: model) {
                                            VStack(alignment: .leading, spacing: 4) {
                                                // 耗时进度条
                                                if stat.avgTTFT > 0 {
                                                    ModelLatencyProgressBar(
                                                        ttft: stat.avgTTFT,
                                                        totalLatency: stat.avgLatency,
                                                        sampleCount: stat.sampleCount
                                                    )
                                                }
                                                
                                                // Token 进度条
                                                if stat.avgInputTokens > 0 || stat.avgOutputTokens > 0 {
                                                    ModelTokenProgressBar(
                                                        inputTokens: stat.avgInputTokens,
                                                        outputTokens: stat.avgOutputTokens
                                                    )
                                                }
                                            }
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
                }
            }
            .listStyle(.sidebar)
        }
        .frame(width: 350, height: 400)
        .background(DesignTokens.Material.glass)
        .task {
            loadLatencyStats()
        }
    }
}

// MARK: - View

extension ModelSelectorView {
    /// 构建供应商分组头部视图
    /// - Parameter provider: 供应商信息
    /// - Returns: 包含供应商图标和名称的头部视图
    @ViewBuilder
    private func sectionHeader(for provider: ProviderInfo) -> some View {
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
        // 设置供应商和模型（会自动保存到项目配置）
        agentProvider.setSelectedProviderId(providerId)
        agentProvider.setSelectedModel(model)

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
        return agentProvider.selectedProviderId == providerId && agentProvider.currentModel == model
    }

    /// 检查模型是否为供应商的默认模型
    /// - Parameters:
    ///   - providerId: 供应商 ID
    ///   - model: 模型名称
    /// - Returns: 是否为默认模型
    private func isDefaultModel(providerId: String, model: String) -> Bool {
        guard let providerType = agentProvider.registry.providerType(forId: providerId) else {
            return false
        }
        return model == providerType.defaultModel
    }

    /// 加载性能统计数据
    private func loadLatencyStats() {
        detailedStats = agentProvider.chatHistoryService.getModelDetailedStats()
        if Self.verbose {
            os_log("\(Self.t)📊 加载到 \(detailedStats.count) 个模型的性能统计")
        }
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

// MARK: - Model Token Progress Bar

/// 模型 Token 进度条组件
struct ModelTokenProgressBar: View {
    let inputTokens: Int
    let outputTokens: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // 进度条
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    // 输入 token 部分（绿色）
                    Rectangle()
                        .fill(Color.green)
                        .frame(width: geometry.size.width * inputRatio)
                    
                    // 输出 token 部分（紫色）
                    Rectangle()
                        .fill(Color.purple)
                        .frame(width: geometry.size.width * (1 - inputRatio))
                }
            }
            .frame(width: 80, height: 3)
            .clipShape(RoundedRectangle(cornerRadius: 1.5))
            
            // Token 信息（一行显示）
            HStack(spacing: 6) {
                HStack(spacing: 1) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 6, weight: .medium))
                    Text("\(inputTokens)")
                        .font(.caption2)
                }
                .foregroundColor(.green)
                
                HStack(spacing: 1) {
                    Image(systemName: "arrow.left.circle.fill")
                        .font(.system(size: 6, weight: .medium))
                    Text("\(outputTokens)")
                        .font(.caption2)
                }
                .foregroundColor(.purple)
            }
        }
        .help(helpText)
    }
    
    /// 输入 token 占总 token 的比例
    private var inputRatio: Double {
        let total = inputTokens + outputTokens
        guard total > 0 else { return 0 }
        return Double(inputTokens) / Double(total)
    }
    
    /// 帮助文本
    private var helpText: String {
        let inputPercent = String(format: "%.1f", inputRatio * 100)
        let outputPercent = String(format: "%.1f", (1 - inputRatio) * 100)
        return """
        ➡️ 输入 Token: \(inputTokens) (\(inputPercent)%)
        ⬅️ 输出 Token: \(outputTokens) (\(outputPercent)%)
        
        输入 Token 表示发送给模型的 token 数量
        输出 Token 表示模型生成的 token 数量
        """
    }
}

// MARK: - Preview

#Preview("ModelSelector") {
    ModelSelectorView()
        .inRootView()
}
