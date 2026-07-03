import Foundation
import Testing
@testable import EditorKernel

@Suite("Editor command category localization")
struct EditorCommandCategoryLocalizationTests {
    @Test("loads simplified Chinese category titles from bundle")
    func loadsSimplifiedChineseCategoryTitles() {
        let locale = Locale(identifier: "zh-Hans")

        #expect(EditorKernelLocalization.string("Navigation", bundle: .module, locale: locale) == "导航")
        #expect(EditorKernelLocalization.string("Chat", bundle: .module, locale: locale) == "对话")
        #expect(EditorKernelLocalization.string("Edit", bundle: .module, locale: locale) == "编辑")
        #expect(EditorKernelLocalization.string("Multi-Cursor", bundle: .module, locale: locale) == "多光标")
    }
}
