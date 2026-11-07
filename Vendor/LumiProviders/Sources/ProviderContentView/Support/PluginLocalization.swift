import Foundation
import LumiLocalizationKit

/// ProviderContentView 作用域的本地化服务（绑定本模块资源 bundle）。
///
/// 原 `LumiPluginLocalization` 转发 shim 已收敛为共享 `PluginLocalization`。
let pluginLocalization = PluginLocalization(bundle: .module)
