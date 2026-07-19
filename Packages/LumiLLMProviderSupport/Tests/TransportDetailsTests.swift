import Foundation
import Testing
@testable import LumiLLMProviderSupport

@Suite("LumiLLMTransportDetails")
struct LumiLLMTransportDetailsTests {
    @Test func truncatedBodyForDisplayKeepsShortText() {
        let text = String(repeating: "a", count: 100)
        #expect(LumiLLMTransportDetails.truncatedBodyForDisplay(text) == text)
    }

    @Test func truncatedBodyForDisplayTruncatesLongText() {
        let text = String(repeating: "x", count: 5_000)
        let truncated = LumiLLMTransportDetails.truncatedBodyForDisplay(text)

        #expect(truncated.hasPrefix(String(repeating: "x", count: LumiLLMTransportDetails.maxBodyDisplayCharacters)))
        #expect(truncated.contains("...[truncated, 5000 characters total]"))
    }
}
