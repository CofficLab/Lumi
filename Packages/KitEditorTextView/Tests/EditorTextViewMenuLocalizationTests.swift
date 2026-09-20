import Foundation
import Testing
@testable import EditorTextView

@Suite("Editor text view menu localization")
struct EditorTextViewMenuLocalizationTests {
    @Test("loads simplified Chinese cut copy paste strings")
    func loadsSimplifiedChineseCutCopyPaste() {
        let locale = Locale(identifier: "zh-Hans")

        #expect(EditorTextViewLocalization.string("Cut", bundle: .module, locale: locale) == "剪切")
        #expect(EditorTextViewLocalization.string("Copy", bundle: .module, locale: locale) == "拷贝")
        #expect(EditorTextViewLocalization.string("Paste", bundle: .module, locale: locale) == "粘贴")
    }
}
