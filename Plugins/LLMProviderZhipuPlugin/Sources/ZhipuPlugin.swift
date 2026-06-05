import Foundation
import SwiftUI
import LumiCoreKit
import SuperLogKit
import os

public struct ZhipuPluginConfiguration: Sendable {
    public var apiKeyProvider: @Sendable () -> String

    public init(apiKeyProvider: @escaping @Sendable () -> String = { "" }) {
        self.apiKeyProvider = apiKeyProvider
    }

    public static let empty = ZhipuPluginConfiguration()
}

/// 智谱 LLM 供应商插件
public actor ZhipuPlugin: SuperPlugin, SuperLog {
    nonisolated(unsafe) public static var configuration: ZhipuPluginConfiguration = .empty
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.zhipu")
    public nonisolated static let emoji = "🔴"
    public nonisolated static let verbose: Bool = true

    public static let id = "LLMProviderZhipu"
    public static let navigationId: String? = nil
    public static let displayName = "智谱"
    public static let description = "Zhipu AI GLM Models"
    public static let iconName = "sparkles"
    public static var category: PluginCategory { .llmProvider }
    public static var order: Int { 10 }

    public nonisolated var instanceLabel: String { Self.id }
    public nonisolated static let policy: PluginPolicy = .alwaysOn

    public static let shared = ZhipuPlugin()

    public nonisolated func llmProviderType() -> (any SuperLLMProvider.Type)? {
        ZhipuProvider.self
    }

    // MARK: - UI Contributions

    /// 添加状态栏尾部视图（显示智谱 GLM 配额状态）
    ///
    /// 仅在当前活跃供应商为智谱且 ViewContainer 支持 AI 聊天时返回视图，
    /// 避免非智谱场景或非 AI 聊天场景下不必要的 UI 和网络请求。
    @MainActor public func addStatusBarTrailingView(context: PluginContext) -> AnyView? {
        guard context.activeProviderId == ZhipuProvider.id, context.showChat else {
            return nil
        }
        return AnyView(ZhipuQuotaStatusBarView())
    }
}
