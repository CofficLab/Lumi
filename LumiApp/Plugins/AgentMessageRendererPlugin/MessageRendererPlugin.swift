import SwiftUI

// MARK: - 核心消息渲染插件

/// 核心消息渲染插件
///
/// 负责注册所有内置消息渲染器，包括：
/// - 用户消息渲染器
/// - 助手消息渲染器
/// - 系统消息渲染器（含工具输出、本地模型加载）
/// - 状态消息渲染器（含轮次结束分隔线）
/// - 错误消息渲染器
///
/// 渲染器实现在 `Renderers/` 目录下，每个渲染器一个文件。
actor MessageRendererPlugin: SuperPlugin {
    static let id = "CoreMessageRenderer"
    static let displayName = String(localized: "核心消息渲染器", table: "CoreMessageRenderer")
    static let description = String(localized: "提供内置消息类型的渲染支持", table: "CoreMessageRenderer")
    static let iconName = "paintbrush.fill"
    static var order: Int { 10 } // 最先加载，确保内置渲染器先注册
    static let enable: Bool = true
    static var isConfigurable: Bool { false } // 核心插件，不可禁用

    @MainActor
    func messageRenderers() -> [any SuperMessageRenderer] {
        [
            // 系统消息渲染器（优先级最高）
            TurnCompletedRenderer(),
            LoadingLocalModelRenderer(),
            ToolOutputRenderer(),

            // 角色消息渲染器
            UserMessageRenderer(),
            AssistantMessageRenderer(),
            SystemMessageRenderer(),
            StatusMessageRenderer(),
            ErrorMessageRenderer(),

            // 兜底渲染器（优先级最低）
            DefaultMarkdownRenderer(),
        ]
    }
}
