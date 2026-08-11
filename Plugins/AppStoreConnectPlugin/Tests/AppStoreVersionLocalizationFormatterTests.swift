import Testing
import Foundation
@testable import AppStoreConnectPlugin

/// Tests for the formatter that turns `AppStoreVersionLocalization` into the
/// multi-line tool result consumed by `ReadAppStoreConnectLocalizationTool`.
@Suite struct AppStoreVersionLocalizationFormatterTests {

    private func sample(
        description: String = "Hello\nWorld",
        whatsNew: String = "",
        keywords: String = "booklet,pdf",
        promotionalText: String = "Make beautiful PDFs",
        supportURL: String = "",
        marketingURL: String = "https://example.com"
    ) -> AppStoreVersionLocalization {
        AppStoreVersionLocalization(
            id: "loc-1",
            locale: "en-US",
            promotionalText: promotionalText,
            description: description,
            keywords: keywords,
            whatsNew: whatsNew,
            supportURL: supportURL,
            marketingURL: marketingURL
        )
    }

    @Test func detailStringIncludesEveryField() {
        let s = AppStoreVersionLocalizationFormatter.detailString(sample())
        #expect(s.contains("id=loc-1"))
        #expect(s.contains("locale=en-US"))
        #expect(s.contains("keywords=booklet,pdf"))
        #expect(s.contains("promotionalText=Make beautiful PDFs"))
        #expect(s.contains("marketingURL=https://example.com"))
    }

    @Test func detailStringPreservesMultilineDescription() {
        let s = AppStoreVersionLocalizationFormatter.detailString(
            sample(description: "line one\nline two\nline three")
        )
        // Real newlines must survive into the tool result so the agent can
        // reason about paragraph structure when planning an edit.
        #expect(s.contains("line one\nline two"))
    }

    @Test func detailStringMarksEmptyURLs() {
        let s = AppStoreVersionLocalizationFormatter.detailString(
            sample(supportURL: "", marketingURL: "")
        )
        #expect(s.contains("supportURL=(empty)"))
        #expect(s.contains("marketingURL=(empty)"))
    }

    @Test func detailStringMarksEmptyStrings() {
        let s = AppStoreVersionLocalizationFormatter.detailString(
            sample(description: "", whatsNew: "", keywords: "")
        )
        #expect(s.contains("description=(empty)"))
        #expect(s.contains("whatsNew=(empty)"))
        #expect(s.contains("keywords=(empty)"))
    }
}

/// Decoder round-trip + copiedMetadata tests for `AppStoreVersionLocalization`.
/// These exist so any future change to the JSON mapping (the very thing the
/// new read-localization tool depends on) fails loudly instead of silently
/// returning empty strings for a real field.
@Suite struct AppStoreVersionLocalizationCodecTests {

    @Test func decodesAllEditableAttributes() throws {
        let json = """
        {
          "id": "abc",
          "attributes": {
            "locale": "zh-Hans",
            "promotionalText": "promo",
            "description": "desc",
            "keywords": "kw",
            "whatsNew": "new",
            "supportUrl": "https://support.example.com",
            "marketingUrl": "https://example.com"
          }
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AppStoreVersionLocalization.self, from: json)
        #expect(decoded.id == "abc")
        #expect(decoded.locale == "zh-Hans")
        #expect(decoded.promotionalText == "promo")
        #expect(decoded.description == "desc")
        #expect(decoded.keywords == "kw")
        #expect(decoded.whatsNew == "new")
        #expect(decoded.supportURL == "https://support.example.com")
        #expect(decoded.marketingURL == "https://example.com")
    }

    @Test func decodesMissingAttributesAsEmpty() throws {
        let json = """
        { "id": "abc", "attributes": { "locale": "en-US" } }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AppStoreVersionLocalization.self, from: json)
        #expect(decoded.promotionalText.isEmpty)
        #expect(decoded.description.isEmpty)
        #expect(decoded.keywords.isEmpty)
        #expect(decoded.whatsNew.isEmpty)
        #expect(decoded.supportURL.isEmpty)
        #expect(decoded.marketingURL.isEmpty)
    }

    @Test func copiedMetadataDropsWhatsNew() {
        let original = AppStoreVersionLocalization(
            id: "x", locale: "en-US",
            promotionalText: "p", description: "d", keywords: "k",
            whatsNew: "release notes", supportURL: "https://s",
            marketingURL: "https://m"
        )
        let copy = AppStoreVersionLocalization.CreateAttributes.copiedMetadata(from: original)
        #expect(copy.promotionalText == "p")
        #expect(copy.description == "d")
        #expect(copy.keywords == "k")
        // whatsNew is intentionally not copied — it belongs to a release,
        // not to the reusable metadata.
        #expect(copy.whatsNew.isEmpty)
        #expect(copy.supportURL == "https://s")
        #expect(copy.marketingURL == "https://m")
    }
}