import Foundation

/// 新版宿主接收 Finder、Dock 或系统“打开文件”事件的能力。
@MainActor
public protocol ExternalFileOpening: AnyObject {
    /// 为插件登记一个文件处理器；返回 `true` 即停止后续分发。
    func registerHandler(pluginID: String, handler: @escaping (URL) -> Bool)
    /// 撤回某插件登记的所有处理器。
    func unregisterHandlers(pluginID: String)
    /// 将外部文件事件分发给已登记处理器。
    @discardableResult func open(_ url: URL) -> Bool
}

@MainActor
public final class DefaultExternalFileOpening: ExternalFileOpening {
    private var handlersByPlugin: [String: [(URL) -> Bool]] = [:]
    private var registrationOrder: [String] = []

    public init() {}

    public func registerHandler(pluginID: String, handler: @escaping (URL) -> Bool) {
        if handlersByPlugin[pluginID] == nil {
            registrationOrder.append(pluginID)
        }
        handlersByPlugin[pluginID, default: []].append(handler)
    }

    public func unregisterHandlers(pluginID: String) {
        handlersByPlugin[pluginID] = nil
        registrationOrder.removeAll { $0 == pluginID }
    }

    public func open(_ url: URL) -> Bool {
        let resolvedURL = url.standardizedFileURL.resolvingSymlinksInPath()
        for pluginID in registrationOrder {
            for handler in handlersByPlugin[pluginID, default: []] where handler(resolvedURL) {
                return true
            }
        }
        return false
    }
}
