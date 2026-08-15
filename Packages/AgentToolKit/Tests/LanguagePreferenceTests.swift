import Foundation
import Testing
@testable import AgentToolKit

struct LanguagePreferenceInitTests {
    @Test
    func chineseLocaleMapsToChinese() {
        #expect(LanguagePreference(locale: Locale(identifier: "zh_CN")) == .chinese)
        #expect(LanguagePreference(locale: Locale(identifier: "zh-TW")) == .chinese)
    }

    @Test
    func englishLocaleMapsToEnglish() {
        #expect(LanguagePreference(locale: Locale(identifier: "en_US")) == .english)
        #expect(LanguagePreference(locale: Locale(identifier: "fr_FR")) == .english)
    }

    @Test
    func currentIsNotNilCase() {
        // 只要能构造出来且是两个 case 之一即可
        #expect([LanguagePreference.chinese, .english].contains(LanguagePreference.current))
    }
}

struct LanguagePreferencePropertyTests {
    @Test
    func localeIdentifierRoundTrip() {
        #expect(LanguagePreference.chinese.localeIdentifier == "zh-Hans")
        #expect(LanguagePreference.english.localeIdentifier == "en")
        #expect(LanguagePreference.chinese.locale.identifier.hasPrefix("zh"))
        #expect(LanguagePreference.english.locale.identifier.hasPrefix("en"))
    }

    @Test
    func allCasesHaveUniqueIds() {
        #expect(Set(LanguagePreference.allCases.map(\.id)).count == LanguagePreference.allCases.count)
    }

    @Test
    func codableRoundTrip() throws {
        let data = try JSONEncoder().encode(LanguagePreference.chinese)
        #expect(try JSONDecoder().decode(LanguagePreference.self, from: data) == .chinese)
    }

    @Test
    func systemPromptDescriptionMatchesLanguage() {
        #expect(LanguagePreference.chinese.systemPromptDescription.contains("中文"))
        #expect(LanguagePreference.english.systemPromptDescription.contains("English"))
    }
}
