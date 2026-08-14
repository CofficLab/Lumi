import Foundation

// MARK: - Web Server Capability Protocol

/// 本地 Web 服务能力协议
///
/// 提供一个仅监听本地回环地址(默认 127.0.0.1)的 HTTP 服务,聚合所有插件通过
/// `LumiPlugin.webRoutes(kernel:)` 贡献的路由。插件的能力(如切换主题)由此暴露
/// 为可被本地工具调用的 HTTP API。
///
/// 协议刻意 **不** 标 `@MainActor`:套接字监听与连接处理在后台线程进行,不应占用
/// 主线程。路由注册(`register`/`unregister`)由 `PluginManager` 在主线程**同步**
/// 发起(与 `registerPromptSuggestions` 等收集逻辑一致);具体实现需自行保证路由表
/// 的线程安全(如用锁),因为请求匹配会在后台线程并发读取该表。
///
/// 与 `NetworkProviding`(出站 HTTP 客户端)互补:本协议是入站服务端。
public protocol WebServerProviding: AnyObject, Sendable {
    /// 监听端口。未启动时为配置端口;启动成功后为实际绑定端口。
    var port: Int { get }

    /// 是否正在监听。
    var isRunning: Bool { get }

    /// 注册(替换)指定插件贡献的一组路由。
    ///
    /// 同一 `pluginID` 再次调用会整体替换其旧路由(幂等替换)。传入空数组等效于
    /// `unregister(pluginID:)`。路由的 `id` 需稳定唯一并建议带插件前缀。
    ///
    /// - Parameters:
    ///   - routes: 该插件贡献的全部路由。
    ///   - pluginID: 归属插件的 `LumiPlugin.id`,用于按插件热卸载。
    func register(_ routes: [WebRoute], forPlugin pluginID: String)

    /// 注销指定插件的所有路由(插件被禁用时调用)。
    func unregister(pluginID: String)

    /// 开始监听端口。已运行则忽略;端口被占用等失败时抛错。
    func start() async throws

    /// 停止监听并释放连接。可重复调用。
    func stop() async
}
