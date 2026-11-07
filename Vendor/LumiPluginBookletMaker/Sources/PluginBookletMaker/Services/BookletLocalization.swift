import BookletMakerCore
import Foundation
import LumiLocalizationKit
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

// MARK: - Domain Error Localization

extension BookletLocalization {
    /// 本地化 ``PDFSplitPlan/ValidationError``。
    ///
    /// `BookletMakerCore` 是纯领域层，不依赖 SwiftUI 与本地化资源，
    /// 因此它的 `errorDescription` 只能给出英文原文；界面层在这里按错误
    /// 的结构化 payload 重新组装本地化文案，未覆盖的分支回退到
    /// `errorDescription`，保证不会退化为空串。
    ///
    /// - Parameter error: 拆分切分点的校验错误。
    /// - Returns: 面向当前语言的错误描述。
    public static func string(for error: PDFSplitPlan.ValidationError) -> String {
        switch error {
        case .invalidToken(let token):
            return string("Invalid page number: %@", token)
        case .cutPointOutOfRange(let page, let pageCount):
            return string(
                "Cut points must be between 1 and %lld (found %lld).",
                Int64(max(pageCount - 1, 0)),
                Int64(page)
            )
        }
    }
}
