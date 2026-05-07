import Foundation
import MagicKit

/// 工具调用循环检测插件
///
/// 提供工具调用循环检测中间件，防止 AI Agent 进入无限循环。
actor ToolCallLoopDetectionPlugin: SuperPlugin, SuperLog {
    nonisolated static let emoji = "🔄"
    nonisolated static let verbose: Bool = false
    static let id = "tool-call-loop-detection"
    static let displayName: String = String(localized: "工具调用循环检测", table: "ToolCallLoopDetection")
    static let description: String = String(localized: "检测并防止工具调用进入无限循环。", table: "ToolCallLoopDetection")
    static let iconName: String = "arrow.triangle.2.circlepath"
    static let isConfigurable: Bool = false
    static let enable: Bool = true
    static var order: Int { 9 }

    static let shared = ToolCallLoopDetectionPlugin()

    private init() {}

    @MainActor
    func sendMiddlewares() -> [AnySuperSendMiddleware] {
        [AnySuperSendMiddleware(ToolCallLoopDetectionSuperSendMiddleware())]
    }
}