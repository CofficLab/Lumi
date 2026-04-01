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