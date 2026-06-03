import SwiftUI

/// 消息渲染器协议
///
/// 插件可以实现此协议来注册自定义消息渲染器。
/// 当消息内容匹配特定条件时，使用自定义视图渲染而非默认的 Markdown 视图。
public protocol SuperMessageRenderer {
    /// 渲染器唯一标识
    static var id: String { get }

    /// 渲染器优先级（数字越大优先级越高，先匹配）
    static var priority: Int { get }

    /// 渲染器实例标识。
    ///
    /// 默认来自静态 `id`，供 type-erased adapter 保留被包装渲染器的真实标识。
    var rendererID: String { get }

    /// 渲染器实例优先级。
    ///
    /// 默认来自静态 `priority`，供 type-erased adapter 保留被包装渲染器的真实优先级。
    var rendererPriority: Int { get }

    /// 判断是否可以渲染该消息
    func canRender(message: ChatMessage) -> Bool

    /// 渲染消息视图
    @MainActor
    func render(message: ChatMessage, showRawMessage: Binding<Bool>) -> AnyView
}

// MARK: - 默认实现

extension SuperMessageRenderer {
    public static var priority: Int { 0 }
    public var rendererID: String { Self.id }
    public var rendererPriority: Int { Self.priority }
}
