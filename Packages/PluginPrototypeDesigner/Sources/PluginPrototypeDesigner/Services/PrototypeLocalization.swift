import Foundation
import KitLocalization

/// Prototype Designer 的运行时本地化入口。
///
/// 与 `PromoLocalization` 同构：统一走 `LumiLocalization`，
/// 保证 SPM 插件 bundle 里的 `.xcstrings` 能被正确解析。
enum PrototypeLocalization {
    static func string(_ key: String) -> String {
        LumiLocalization.string(key, bundle: .module, table: "Localizable", locale: .current)
    }
}
