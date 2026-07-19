import Foundation

// MARK: - Default Send Middleware Provider

/// 默认发送中间件服务实现
///
/// 负责管理发送中间件的注册和执行。
@MainActor
public final class DefaultSendMiddlewareProviding: SendMiddlewareProviding {
    public private(set) var allSendMiddlewares: [any SendMiddleware] = []

    private var sendMiddlewares: [String: any SendMiddleware] = [:]
    private var sendMiddlewareOrder: [String] = []

    public init() {}

    public func registerSendMiddleware(_ middleware: any SendMiddleware, id: String? = nil) {
        let middlewareId = id ?? UUID().uuidString
        if sendMiddlewares[middlewareId] == nil {
            sendMiddlewareOrder.append(middlewareId)
        }
        sendMiddlewares[middlewareId] = middleware
        updateSortedMiddlewares()
    }

    public func unregisterSendMiddleware(id: String) {
        sendMiddlewares.removeValue(forKey: id)
        sendMiddlewareOrder.removeAll { $0 == id }
        updateSortedMiddlewares()
    }

    private func updateSortedMiddlewares() {
        allSendMiddlewares = sendMiddlewareOrder.compactMap { sendMiddlewares[$0] }
    }
}
