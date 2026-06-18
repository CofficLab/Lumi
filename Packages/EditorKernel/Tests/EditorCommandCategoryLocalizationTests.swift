import Foundation
import Testing
import LumiCoreKit
@testable import EditorKernel

@Suite("Editor command category localization")
struct EditorCommandCategoryLocalizationTests {
    @Test("loads simplified Chinese category titles from bundle")
    func loadsSimplifiedChineseCategoryTitles() {
        let locale = Locale(identifier: "zh-Hans")

        #expect(LumiPluginLocalization.string("Navigation", bundle: .module, locale: locale) == "导航")
        #expect(LumiPluginLocalization.string("Chat", bundle: .module, locale: locale) == "对话")
        #expect(LumiPluginLocalization.string("Edit", bundle: .module, locale: locale) == "编辑")
        #expect(LumiPluginLocalization.string("Multi-Cursor", bundle: .module, locale: locale) == "多光标")
    }
}
