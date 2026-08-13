import Foundation
import LocalizationKit
import SwiftUI

// MARK: - Booklet Localization Helper

/// Runtime localization helper for the Booklet Maker plugin bundle.
///
/// Wraps ``LumiLocalization`` so call sites stay short and consistent
/// across views, view models, and services.
///
/// 该类型是 public 的：iOS Factory（`FactoryBookletMakerMobile`）自身没有资源 bundle，
/// 需要复用本插件的 `Localizable.xcstrings` 目录来翻译导航与工具栏文案。
public enum BookletLocalization {
    static let table = "Localizable"
    static let bundle = Bundle.module

    public static func string(_ key: String) -> String {
        LumiLocalization.string(key, bundle: bundle, table: table)
    }

    public static func string(_ key: String, _ args: CVarArg...) -> String {
        String(format: string(key),
               locale: LumiLocalization.preferredLocale(),
               arguments: args)
    }
}
