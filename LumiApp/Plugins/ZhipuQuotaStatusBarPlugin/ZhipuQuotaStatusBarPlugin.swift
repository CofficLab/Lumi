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
