import Foundation
import Testing
import LumiCoreKit
@testable import EditorTextView

@Suite("Editor text view menu localization")
struct EditorTextViewMenuLocalizationTests {
    @Test("loads simplified Chinese cut copy paste strings")
    func loadsSimplifiedChineseCutCopyPaste() {
        let locale = Locale(identifier: "zh-Hans")

        #expect(LumiPluginLocalization.string("Cut", bundle: .module, locale: locale) == "剪切")
        #expect(LumiPluginLocalization.string("Copy", bundle: .module, locale: locale) == "拷贝")
        #expect(LumiPluginLocalization.string("Paste", bundle: .module, locale: locale) == "粘贴")
    }
}
