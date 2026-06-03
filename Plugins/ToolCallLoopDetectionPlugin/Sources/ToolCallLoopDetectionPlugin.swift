import Foundation
import LumiCoreKit
import SuperLogKit
import AgentToolKit
import os

/// 工具调用循环检测插件
///
/// 提供工具调用循环检测中间件，防止 AI Agent 进入无限循环。
public actor ToolCallLoopDetectionPlugin: SuperPlugin, SuperLog {
    public nonisolated static let policy: PluginPolicy = .disabled
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.tool-call-loop-detection")
    public nonisolated static let emoji = "🔄"
    public nonisolated static let verbose: Bool = true
    public static let id = "tool-call-loop-detection"
    public static let displayName: String = String(localized: "工具调用循环检测", bundle: .module)
    public static let description: String = String(localized: "检测并防止工具调用进入无限循环。", bundle: .module)
    public static let iconName: String = "arrow.triangle.2.circlepath"
    public static var category: PluginCategory { .agent }
    public static var order: Int { 9 }

    public static let shared = ToolCallLoopDetectionPlugin()

    private init() {}

    @MainActor
    public func sendMiddlewares() -> [AnySuperSendMiddleware] {
        [AnySuperSendMiddleware(ToolCallLoopDetectionSuperSendMiddleware())]
    }
}
