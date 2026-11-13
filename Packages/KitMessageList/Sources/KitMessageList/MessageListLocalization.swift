import Foundation
import LumiLocalizationKit

/// Kit 作用域的本地化服务（绑定 Kit 资源 bundle）。
///
/// 共享代码里的文案（首屏遮罩、会话活动行、分页按钮）统一走这里；
/// 各插件自己的文案仍由插件内的 `pluginLocalization` 解析。
public let messageListLocalization = PluginLocalization(bundle: .module)
