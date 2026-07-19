import Foundation

// MARK: - Send Middleware Capability Protocol

/// 发送中间件能力协议
///
/// 定义 LumiCore 需要的发送中间件管理功能，由具体布局插件实现。
/// 负责管理发送中间件的注册和执行。
@MainActor
public protocol SendMiddlewareProviding: ObservableObject {
    /// 所有已注册的发送中间件
    var allSendMiddlewares: [any SendMiddleware] { get }

    /// 注册发送中间件
    func registerSendMiddleware(_ middleware: any SendMiddleware, id: String?)

    /// 注销发送中间件
    func unregisterSendMiddleware(id: String)
}
