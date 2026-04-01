import SwiftUI

// MARK: - 消息渲染器协议

/// 消息渲染器协议
///
/// 插件可以实现此协议来注册自定义消息渲染器。
/// 当消息内容匹配特定条件时，使用自定义视图渲染而非默认的 Markdown 视图。
///
/// ## 使用示例
///
/// ```swift
/// struct LoadingModelRenderer: SuperMessageRenderer {
///     static let id = "loading-model"
///     static let priority = 100
///
///     func canRender(message: ChatMessage) -> Bool {
///         message.content == "__MY_PLUGIN_LOADING__"
///     }
///
///     @ViewBuilder
///     func render(message: ChatMessage) -> some View {
///         HStack {
///             ProgressView()
///             Text("正在加载模型...")
///         }
///     }
/// }
/// ```
protocol SuperMessageRenderer {
    /// 渲染器唯一标识
    static var id: String { get }
    
    /// 渲染器优先级（数字越大优先级越高，先匹配）
    static var priority: Int { get }
    
    /// 判断是否可以渲染该消息
    ///
    /// - Parameter message: 要渲染的消息
    /// - Returns: true 表示可以渲染，false 表示不匹配
    func canRender(message: ChatMessage) -> Bool
    
    /// 渲染消息视图
    ///
    /// - Parameter message: 要渲染的消息
    /// - Returns: 自定义视图
    @MainActor
    func render(message: ChatMessage, showRawMessage: Binding<Bool>) -> AnyView
}

// MARK: - 默认实现

extension SuperMessageRenderer {
    static var priority: Int { 0 }
}

// MARK: - 消息渲染器注册表

/// 消息渲染器注册表
///
/// 全局单例，管理所有注册的消息渲染器。
/// 插件可以在 `onRegister()` 中注册自定义渲染器。
///
/// ## 使用示例
///
/// ```swift
/// actor MyPlugin: SuperPlugin {
///     nonisolated func onRegister() {
///         MessageRendererRegistry.shared.register(LoadingModelRenderer())
///     }
/// }
/// ```
@MainActor
final class MessageRendererRegistry: ObservableObject {
    static let shared = MessageRendererRegistry()
    
    @Published private(set) var renderers: [any SuperMessageRenderer] = []
    
    private init() {
        // 注册内置渲染器（优先级最低）
        registerBuiltinRenderers()
    }
    
    /// 注册渲染器
    func register(_ renderer: some SuperMessageRenderer) {
        // 检查是否已存在相同 ID 的渲染器
        if let index = renderers.firstIndex(where: { type(of: $0).id == type(of: renderer).id }) {
            renderers[index] = renderer
        } else {
            renderers.append(renderer)
        }
        
        // 按优先级降序排序
        renderers.sort { type(of: $0).priority > type(of: $1).priority }
    }
    
    /// 批量注册渲染器
    func register(_ renderers: [any SuperMessageRenderer]) {
        renderers.forEach { register($0) }
    }
    
    /// 注销渲染器
    func unregister(id: String) {
        renderers.removeAll { type(of: $0).id == id }
    }
    
    /// 清空所有渲染器
    func clear() {
        renderers.removeAll()
    }
    
    /// 查找匹配的渲染器
    ///
    /// 按优先级顺序查找，返回第一个匹配的渲染器。
    ///
    /// - Parameter message: 要渲染的消息
    /// - Returns: 匹配的渲染器，如果没有则返回 nil
    func findRenderer(for message: ChatMessage) -> (any SuperMessageRenderer)? {
        renderers.first { $0.canRender(message: message) }
    }
    
    // MARK: - 内置渲染器
    
    private func registerBuiltinRenderers() {
        // 注册系统消息渲染器
        register(TurnCompletedRenderer())
        register(LoadingLocalModelRenderer())
        register(ToolOutputRenderer())
        register(ErrorMessageRenderer())
    }
}

// MARK: - 内置渲染器示例

/// 对话轮次结束分隔线渲染器
private struct TurnCompletedRenderer: SuperMessageRenderer {
    static let id = "turn-completed"
    static let priority = 100
    
    func canRender(message: ChatMessage) -> Bool {
        message.content == ChatMessage.turnCompletedSystemContentKey
    }
    
    @MainActor
    func render(message: ChatMessage, showRawMessage: Binding<Bool>) -> AnyView {
        AnyView(TurnCompletedDivider(message: message))
    }
}

/// 本地模型加载状态渲染器
private struct LoadingLocalModelRenderer: SuperMessageRenderer {
    static let id = "loading-local-model"
    static let priority = 100
    
    func canRender(message: ChatMessage) -> Bool {
        message.content == ChatMessage.loadingLocalModelSystemContentKey
            || message.content == ChatMessage.loadingLocalModelDoneSystemContentKey
    }
    
    @MainActor
    func render(message: ChatMessage, showRawMessage: Binding<Bool>) -> AnyView {
        AnyView(
            VStack(alignment: .leading, spacing: 4) {
                MessageHeaderView {
                    AppIdentityRow(
                        title: "System",
                        titleColor: AppUI.Color.semantic.textSecondary
                    )
                } trailing: {
                    HStack(alignment: .center, spacing: 12) {
                        Text(formatTimestamp(message.timestamp))
                            .font(AppUI.Typography.caption2)
                            .foregroundColor(AppUI.Color.semantic.textSecondary)
                    }
                }
                
                LoadingLocalModelSystemMessageView(message: message)
                    .messageBubbleStyle(role: message.role, isError: false)
            }
        )
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(for: date) ?? ""
    }
}

/// 工具输出渲染器
private struct ToolOutputRenderer: SuperMessageRenderer {
    static let id = "tool-output"
    static let priority = 90
    
    func canRender(message: ChatMessage) -> Bool {
        message.role == .system && message.isToolOutput
    }
    
    @MainActor
    func render(message: ChatMessage, showRawMessage: Binding<Bool>) -> AnyView {
        AnyView(
            VStack(alignment: .leading, spacing: 4) {
                RoleLabel.tool
                ToolOutputView(message: message)
            }
        )
    }
}

/// 错误消息渲染器
private struct ErrorMessageRenderer: SuperMessageRenderer {
    static let id = "error-message"
    static let priority = 80
    
    func canRender(message: ChatMessage) -> Bool {
        message.role == .error || message.isError
    }
    
    @MainActor
    func render(message: ChatMessage, showRawMessage: Binding<Bool>) -> AnyView {
        AnyView(ErrorMessage(message: message, showRawMessage: showRawMessage))
    }
}

// MARK: - 视图扩展

extension View {
    /// 使用注册表渲染消息
    @ViewBuilder
    static func renderMessage(
        message: ChatMessage,
        showRawMessage: Binding<Bool>,
        defaultContent: () -> some View
    ) -> some View {
        if let renderer = MessageRendererRegistry.shared.findRenderer(for: message) {
            renderer.render(message: message, showRawMessage: showRawMessage)
        } else {
            defaultContent()
        }
    }
}