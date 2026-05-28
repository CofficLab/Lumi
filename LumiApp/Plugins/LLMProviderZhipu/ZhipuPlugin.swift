import Foundation
import SwiftUI
import LumiCoreKit
import os

/// 智谱 LLM 供应商插件
actor ZhipuPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.zhipu")
    nonisolated static let emoji = "🔴"
    nonisolated static let verbose: Bool = true

    static let id = "LLMProviderZhipu"
    static let navigationId: String? = nil
    static let displayName = "智谱"
    static let description = "Zhipu AI GLM Models"
    static let iconName = "sparkles"
    static var category: PluginCategory { .llmProvider }
    static var order: Int { 10 }

    nonisolated var instanceLabel: String { Self.id }
    static let shared = ZhipuPlugin()

    nonisolated func llmProviderType() -> (any SuperLLMProvider.Type)? {
        ZhipuProvider.self
    }

    // MARK: - UI Contributions

    /// 添加状态栏尾部视图（显示智谱 GLM 配额状态）
    ///
    /// 仅在当前活跃供应商为智谱且 ViewContainer 支持 AI 聊天时返回视图，
    /// 避免非智谱场景或非 AI 聊天场景下不必要的 UI 和网络请求。
    @MainActor func addStatusBarTrailingView(context: PluginContext) -> AnyView? {
        guard context.activeProviderId == ZhipuProvider.id, context.supportsAIChat else {
            return nil
        }
        return AnyView(ZhipuQuotaStatusBarView())
    }
}
