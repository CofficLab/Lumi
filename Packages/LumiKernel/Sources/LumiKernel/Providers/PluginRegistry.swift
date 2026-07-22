import Foundation

/// 提供所有已注册插件列表的协议
///
/// 用于需要访问插件列表的服务，如 Theme 收集等。
@MainActor
public protocol PluginRegistry: AnyObject {
    /// 所有已注册的插件
    var allPlugins: [LumiPlugin] { get }
}
