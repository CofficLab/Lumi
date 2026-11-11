import Foundation
import LumiLocalizationKit

/// 插件作用域的本地化服务（绑定本模块资源 bundle）。
///
/// 调用点使用 `pluginLocalization.string(_:)`。
public let pluginLocalization = PluginLocalization(bundle: .module)
