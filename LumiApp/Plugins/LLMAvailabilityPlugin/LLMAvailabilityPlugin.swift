import MagicKit
import os
import SwiftUI

/// LLM 可用性检测插件
/// 通过向每个供应商的每个模型发送 ping 请求，维护实际可用的供应商+模型列表
///
/// 该插件通过 addRootView 注入，利用环境中的 LLMVM 和 LLMService 获取所有供应商和模型，
/// 然后逐一检测可用性，将结果存储到 LLMAvailabilityStore 中。
actor LLMAvailabilityPlugin: SuperPlugin {
    /// 插件专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.llm-availability")

    nonisolated static let emoji = "🔍"
    nonisolated static let verbose: Bool = false
    static let id = "LLMAvailability"
    static let displayName = String(localized: "LLM Availability", table: "LLMAvailability")
    static let description = String(localized: "Detect available LLM providers and models via health checks", table: "LLMAvailability")
    static let iconName = "network"
    static var order: Int { 15 }
    static let enable: Bool = false

    /// 用户可在设置中启用/禁用此插件
    static var isConfigurable: Bool { true }

    static let shared = LLMAvailabilityPlugin()

    nonisolated func onRegister() {}
    nonisolated func onEnable() {}
    nonisolated func onDisable() {}

    @MainActor
    func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        AnyView(LLMAvailabilityOverlay(content: content()))
    }

    @MainActor
    func agentTools() -> [SuperAgentTool] {
        [
            ListAvailableModelsTool(),
        ]
    }

    @MainActor
    func sendMiddlewares() -> [AnySuperSendMiddleware] {
        []
    }
}
