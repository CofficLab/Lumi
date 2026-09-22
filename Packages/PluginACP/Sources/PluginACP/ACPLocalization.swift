import Foundation
import KitLocalization

/// PluginACP 的本地化查询。
///
/// ACP 面向外部编辑器，权限选项等文案会直接出现在客户端 UI 中，因此必须
/// 跟随系统语言，不能硬编码中文。
enum ACPLocalization {
    static func string(_ key: String, locale: Locale = .current) -> String {
        LumiLocalization.string(key, bundle: .module, table: "Localizable", locale: locale)
    }

    /// 带单个参数的本地化（用于 `Input required: %@`）。
    static func string(_ key: String, _ argument: String, locale: Locale = .current) -> String {
        String(
            format: string(key, locale: locale),
            locale: locale,
            arguments: [argument]
        )
    }

    // MARK: - Keys

    /// 权限选项：允许。
    static var allow: String { string("Allow") }
    /// 权限选项：拒绝。
    static var reject: String { string("Reject") }
    /// 权限选项：是。
    static var yes: String { string("Yes") }
    /// 权限选项：否。
    static var no: String { string("No") }
    /// 工具授权默认提问。
    static var allowThisOperation: String { string("Allow this operation?") }

    /// AskUser 降级提示（ACP 无自由文本通道）。
    static func inputRequired(_ question: String) -> String {
        string("Input required: %@", question)
    }
}
