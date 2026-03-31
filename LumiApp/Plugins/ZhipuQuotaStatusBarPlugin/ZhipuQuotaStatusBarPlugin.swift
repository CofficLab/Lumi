import MagicKit
import SwiftUI
import Foundation
import os

/// 智谱 GLM 配额状态栏插件：在 Agent 模式底部状态栏显示智谱 GLM Coding Plan 的 5 小时配额状态
actor ZhipuQuotaStatusBarPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.zhipu-quota-status-bar")
    nonisolated static let emoji = "📊"
    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = false

    static let id: String = "ZhipuQuotaStatusBar"
    static let navigationId: String? = nil
    static let displayName: String = String(localized: "Zhipu GLM Quota", table: "ZhipuQuotaStatusBar")
    static let description: String = String(localized: "Display Zhipu GLM Coding Plan quota status in status bar", table: "ZhipuQuotaStatusBar")
    static let iconName: String = "chart.bar.fill"
    static let isConfigurable: Bool = false
    static var order: Int { 96 }

    nonisolated var instanceLabel: String { Self.id }
    static let shared = ZhipuQuotaStatusBarPlugin()

    // MARK: - UI Contributions

    /// 添加状态栏尾部视图（仅在当前使用 Zhipu 供应商时显示）
    @MainActor func addStatusBarTrailingView() -> AnyView? {
        if Self.verbose {
            Self.logger.info("\(Self.t)提供 ZhipuQuotaStatusBarView")
        }
        return AnyView(ZhipuQuotaStatusBarView())
    }
}

// MARK: - Status Bar View

/// 智谱 GLM 配额状态栏视图
struct ZhipuQuotaStatusBarView: View {
    @EnvironmentObject private var llmVM: LLMVM
    @State private var quotaStatus: ZhipuQuotaStatus = .loading
    @State private var lastUpdateTime: Date?
    @State private var timer: Timer?

    // 缓存策略：5 分钟内不重复请求
    private let cacheTTL: TimeInterval = 300 // 5 分钟
    private var shouldRefresh: Bool {
        guard let lastUpdate = lastUpdateTime else { return true }
        return Date().timeIntervalSince(lastUpdate) > cacheTTL
    }

    /// 判断是否应该显示（仅在 Zhipu 供应商激活时）
    private var shouldShow: Bool {
        llmVM.selectedProviderId == "zhipu"
    }

    var body: some View {
        Group {
            if shouldShow {
                switch quotaStatus {
                case .loading:
                    loadingView
                case .success(let data):
                    successView(data)
                case .authError:
                    errorView("认证过期")
                case .unavailable:
                    errorView("配额不可用")
                }
            }
        }
        .onAppear {
            if shouldShow {
                refreshQuota()
                startTimer()
            }
        }
        .onChange(of: llmVM.selectedProviderId) { _, newId in
            // 监听供应商切换
            if newId == "zhipu" {
                // 切换到 Zhipu，刷新配额并启动定时器
                refreshQuota()
                startTimer()
            } else {
                // 切换到其他供应商，停止定时器
                stopTimer()
            }
        }
        .onDisappear {
            stopTimer()
        }
    }

    /// 加载视图
    private var loadingView: some View {
        StatusBarHoverContainer(
            detailView: ZhipuQuotaDetailView(status: quotaStatus),
            id: "zhipu-quota-status"
        ) {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 10))

                Text("加载中...")
                    .font(.system(size: 11))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }

    /// 成功视图
    private func successView(_ data: ZhipuQuotaData) -> some View {
        StatusBarHoverContainer(
            detailView: ZhipuQuotaDetailView(status: quotaStatus),
            id: "zhipu-quota-status"
        ) {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 10))

                Text(data.statusText)
                    .font(.system(size: 11))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }

    /// 错误视图
    private func errorView(_ message: String) -> some View {
        StatusBarHoverContainer(
            detailView: ZhipuQuotaDetailView(status: quotaStatus),
            id: "zhipu-quota-status"
        ) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.orange)

                Text(message)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }

    // MARK: - Timer

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            // 仅在当前使用 Zhipu 供应商时刷新
            guard shouldShow else { return }
            
            if shouldRefresh {
                refreshQuota()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Data Fetching

    private func refreshQuota() {
        Task {
            let result = await ZhipuQuotaHelper.fetchQuota()
            await MainActor.run {
                quotaStatus = result.status
                lastUpdateTime = Date()

                if case .success(let data) = result.status {
                    ZhipuQuotaStatusBarPlugin.logger.info("智谱 GLM 配额更新: \(data.statusText)")
                } else {
                    ZhipuQuotaStatusBarPlugin.logger.warning("智谱 GLM 配额获取失败")
                }
            }
        }
    }
}

// MARK: - Quota Detail View

/// 智谱 GLM 配额详情视图（在 popover 中显示）
struct ZhipuQuotaDetailView: View {
    let status: ZhipuQuotaStatus

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            // 标题
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 16))
                    .foregroundColor(DesignTokens.Color.semantic.primary)

                Text("智谱 GLM 配额")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                Spacer()
            }

            Divider()

            switch status {
            case .loading:
                loadingContent
            case .success(let data):
                quotaContent(data)
            case .authError:
                authErrorContent
            case .unavailable:
                unavailableContent
            }
        }
    }

    /// 加载内容
    private var loadingContent: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            ProgressView()
                .scaleEffect(0.8)

            Text("正在获取配额信息...")
                .font(.system(size: 13))
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignTokens.Spacing.lg)
    }

    /// 配额内容
    private func quotaContent(_ data: ZhipuQuotaData) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            // 等级
            QuotaInfoRow(label: "等级", value: data.levelDisplay)

            // 进度条
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("使用进度")
                        .font(.system(size: 12))
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)

                    Spacer()

                    Text("\(data.usedPercent)%")
                        .font(.system(size: 12))
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                }

                ProgressView(value: Double(data.usedPercent) / 100.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: progressColor(data.usedPercent)))

                HStack {
                    Text("剩余 \(data.leftPercent)%")
                        .font(.system(size: 11))
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)

                    Spacer()

                    Text("总时长 5 小时")
                        .font(.system(size: 11))
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                }
            }

            Divider()

            // 重置时间
            QuotaInfoRow(label: "重置时间", value: data.resetTime)

            // 状态说明
            VStack(alignment: .leading, spacing: 4) {
                Text("说明")
                    .font(.system(size: 12))
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)

                Text("智谱 GLM Coding Plan 采用 5 小时滚动窗口配额。配额会在使用后逐渐恢复。")
                    .font(.system(size: 11))
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                    .lineLimit(3)
            }
        }
    }

    /// 认证错误内容
    private var authErrorContent: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundColor(DesignTokens.Color.semantic.warning)

            Text("认证已过期")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(DesignTokens.Color.semantic.textPrimary)

            Text("请检查智谱 AI API Key 是否正确配置")
                .font(.system(size: 12))
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignTokens.Spacing.lg)
    }

    /// 不可用内容
    private var unavailableContent: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundColor(DesignTokens.Color.semantic.warning)

            Text("配额信息不可用")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(DesignTokens.Color.semantic.textPrimary)

            Text("请检查网络连接或稍后重试")
                .font(.system(size: 12))
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignTokens.Spacing.lg)
    }

    /// 根据百分比返回进度条颜色
    private func progressColor(_ percent: Int) -> Color {
        if percent < 50 {
            return .green
        } else if percent < 80 {
            return .orange
        } else {
            return .red
        }
    }
}

/// 配额信息行
struct QuotaInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                .frame(width: 70, alignment: .leading)

            Text(value)
                .font(.system(size: 12))
                .foregroundColor(DesignTokens.Color.semantic.textPrimary)

            Spacer()
        }
    }
}

// MARK: - Models

/// 智谱配额状态
enum ZhipuQuotaStatus {
    case loading
    case success(ZhipuQuotaData)
    case authError
    case unavailable
}

/// 智谱配额数据
struct ZhipuQuotaData {
    let level: String
    let usedPercent: Int
    let leftPercent: Int
    let nextResetTime: TimeInterval

    /// 等级显示文本
    var levelDisplay: String {
        "GLM \(level.isEmpty ? "Lite" : level)"
    }

    /// 重置时间文本
    var resetTime: String {
        let date = Date(timeIntervalSince1970: nextResetTime)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    /// 状态栏显示文本
    var statusText: String {
        "\(levelDisplay) | 剩余 \(leftPercent)% | 重置 \(resetTime)"
    }
}

// MARK: - Quota Helper

/// 智谱配额查询辅助工具
enum ZhipuQuotaHelper {
    /// 默认配额 API 端点
    private static let defaultQuotaURL = "https://bigmodel.cn/api/monitor/usage/quota/limit"

    /// 请求超时时间（秒）
    private static let timeout: TimeInterval = 5.0

    /// 获取配额信息
    /// - Returns: 配额结果
    static func fetchQuota() async -> (status: ZhipuQuotaStatus, data: ZhipuQuotaData?) {
        // 获取 API Key
        let apiKey = APIKeyStore.shared.string(forKey: "DevAssistant_ApiKey_Zhipu") ?? ""
        guard !apiKey.isEmpty else {
            return (.authError, nil)
        }

        // 获取 Base URL（推断配额 URL）
        let baseURL = "https://open.bigmodel.cn"
        let quotaURL = "\(baseURL)/api/monitor/usage/quota/limit"

        guard let url = URL(string: quotaURL) else {
            return (.unavailable, nil)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = timeout

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return (.unavailable, nil)
            }

            // 认证失败
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 1001 {
                return (.authError, nil)
            }

            // 其他错误
            guard httpResponse.statusCode == 200 else {
                return (.unavailable, nil)
            }

            // 解析 JSON
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let payload = json else {
                return (.unavailable, nil)
            }

            // 检查 success 字段
            if payload["success"] as? Bool != true {
                let code = payload["code"] as? Int
                if code == 1001 || code == 401 {
                    return (.authError, nil)
                }
                return (.unavailable, nil)
            }

            // 提取配额数据
            guard let dataDict = payload["data"] as? [String: Any],
                  let limits = dataDict["limits"] as? [[String: Any]] else {
                return (.unavailable, nil)
            }

            // 查找 5 小时滚动窗口限制
            let rollingLimit = limits.first { limit in
                (limit["type"] as? String) == "TOKENS_LIMIT" && (limit["number"] as? Int) == 5
            }

            if let rollingLimit = rollingLimit,
               let percentage = rollingLimit["percentage"] as? Int,
               let nextResetTime = rollingLimit["nextResetTime"] as? TimeInterval {
                let usedPercent = min(100, max(0, percentage))
                let leftPercent = 100 - usedPercent
                let level = (dataDict["level"] as? String) ?? ""

                return (.success(ZhipuQuotaData(
                    level: level,
                    usedPercent: usedPercent,
                    leftPercent: leftPercent,
                    nextResetTime: nextResetTime
                )), nil)
            }

            // 查找时间限制（备用方案）
            let timeLimit = limits.first { limit in
                (limit["type"] as? String) == "TIME_LIMIT" && (limit["unit"] as? Int) == 5
            }

            if let timeLimit = timeLimit,
               let remaining = timeLimit["remaining"] as? Int,
               let usage = timeLimit["usage"] as? Int,
               let nextResetTime = timeLimit["nextResetTime"] as? TimeInterval {
                let total = remaining + usage
                let usedPercent = total > 0 ? Int((Double(usage) / Double(total)) * 100) : 0
                let leftPercent = 100 - usedPercent
                let level = (dataDict["level"] as? String) ?? ""

                return (.success(ZhipuQuotaData(
                    level: level,
                    usedPercent: usedPercent,
                    leftPercent: leftPercent,
                    nextResetTime: nextResetTime
                )), nil)
            }

            return (.unavailable, nil)

        } catch {
            return (.unavailable, nil)
        }
    }
}

// MARK: - Preview

#Preview {
    ZhipuQuotaStatusBarView()
        .frame(height: 30)
        .inRootView()
}

#Preview("Detail View - Success") {
    ZhipuQuotaDetailView(status: .success(ZhipuQuotaData(
        level: "Lite",
        usedPercent: 27,
        leftPercent: 73,
        nextResetTime: Date().addingTimeInterval(3600).timeIntervalSince1970
    )))
    .frame(width: 400)
}

#Preview("Detail View - Auth Error") {
    ZhipuQuotaDetailView(status: .authError)
        .frame(width: 400)
}

#Preview("Detail View - Unavailable") {
    ZhipuQuotaDetailView(status: .unavailable)
        .frame(width: 400)
}
