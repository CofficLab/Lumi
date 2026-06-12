import Foundation
import Testing
import LumiCoreKit
@testable import EditorChatIntegrationPlugin

@Suite("Editor chat integration localization")
struct EditorChatIntegrationLocalizationTests {
    @Test("plugin bundle includes localized strings catalog")
    func pluginBundleIncludesLocalizedStringsCatalog() {
        let hasCatalog = Bundle.module.url(forResource: "Localizable", withExtension: "xcstrings") != nil
        let hasCompiledStrings = Bundle.module.path(forResource: "zh-Hans", ofType: "lproj") != nil
        #expect(hasCatalog || hasCompiledStrings)
    }

    @Test("loads simplified Chinese strings from plugin bundle")
    func loadsSimplifiedChineseStrings() {
        let locale = Locale(identifier: "zh-Hans")
        #expect(LumiPluginLocalization.string("Chat Integration", bundle: .module, locale: locale) == "聊天集成")
        #expect(LumiPluginLocalization.string("Add Selection to Chat", bundle: .module, locale: locale) == "添加选中内容到对话")
        #expect(LumiPluginLocalization.string("Add Location to Chat", bundle: .module, locale: locale) == "添加位置到对话")
        #expect(
            LumiPluginLocalization.string(
                "Adds context menu actions to send code and locations to the AI chat.",
                bundle: .module,
                locale: locale
            ) == "添加上下文菜单操作，将代码和位置发送到 AI 对话。"
        )
    }

    @Test("string catalog defines required languages")
    func stringCatalogDefinesRequiredLanguages() throws {
        let catalogURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Localizable.xcstrings")
        let data = try Data(contentsOf: catalogURL)
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try #require(json["strings"] as? [String: Any])
        let requiredLanguages = ["en", "zh-Hans", "zh-HK", "zh-TW", "zh-Hant"]

        for (key, value) in strings {
            let entry = try #require(value as? [String: Any], "Invalid entry for \(key)")
            guard let localizations = entry["localizations"] as? [String: Any] else { continue }
            for language in requiredLanguages {
                #expect(localizations[language] != nil, "Missing \(language) for \(key)")
            }
        }
    }
}
