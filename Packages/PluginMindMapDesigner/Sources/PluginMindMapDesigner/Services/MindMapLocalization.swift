import Foundation
import KitLocalization

/// 思维导图插件的轻量本地化（KernelCore 体系）。
///
/// 与旧版内联双语不同，新版对齐 `PromoLocalization` / `AppIconDesignerLocalization`：
/// 通过 `Localizable.xcstrings` 查表（key 为英文原文），由 `KitLocalization` 统一解析。
public enum MindMapLocalization {
    static func string(_ key: String) -> String {
        LumiLocalization.string(key, bundle: .module, table: "Localizable", locale: .current)
    }
}
