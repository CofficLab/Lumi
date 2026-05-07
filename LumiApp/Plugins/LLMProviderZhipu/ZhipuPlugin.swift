import Foundation
import SwiftUI
import os
import MagicKit

/// 智谱 LLM 供应商插件
actor ZhipuPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.zhipu")
    nonisolated static let emoji = "🔴"
    nonisolated static let verbose: Bool = false

    static let id = "LLMProviderZhipu"
    static let navigationId: String? = nil
    static let displayName = "智谱"
    static let description = "Zhipu AI GLM Models"
    static let iconName = "sparkles"
    static let isConfigurable: Bool = false
    static var order: Int { 10 }
    static let enable: Bool = true

    nonisolated var instanceLabel: String { Self.id }
    static let shared = ZhipuPlugin()

    nonisolated func llmProviderType() -> (any SuperLLMProvider.Type)? {
        ZhipuProvider.self
    }

    // MARK: - UI Contributions

    /// 添加状态栏尾部视图（显示智谱 GLM 配额状态）
    @MainActor func addStatusBarTrailingView(activeIcon: String?) -> AnyView? {
        if Self.verbose {
            Self.logger.info("\(Self.t)提供 ZhipuQuotaStatusBarView")
        }
        return AnyView(ZhipuQuotaStatusBarView())
    }
}
