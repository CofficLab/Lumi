import Foundation
import LumiLocalizationKit

/// 插件作用域的本地化服务（绑定本模块资源 bundle）。
///
/// 与其它插件一致：调用点使用 `pluginLocalization.string(_:)`，
/// 未命中时回退为原始 key，保证界面不会空白。
let pluginLocalization = PluginLocalization(bundle: .module)
