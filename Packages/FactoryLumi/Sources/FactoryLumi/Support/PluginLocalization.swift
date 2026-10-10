import Foundation
import LumiLocalizationKit

/// 插件作用域的本地化服务（绑定本模块资源 bundle）。
///
/// 由原 `LumiPluginLocalization` 转发 shim 收敛而来；调用点使用 `pluginLocalization.string(_:)`。
let pluginLocalization = PluginLocalization(bundle: .module)

/// 指向主 App bundle 的本地化服务（用于 `Bundle.main` 场景）。
let pluginLocalizationMain = PluginLocalization(bundle: .main)
