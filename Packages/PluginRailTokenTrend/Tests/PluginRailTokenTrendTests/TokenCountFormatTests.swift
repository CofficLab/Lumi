import Testing
@testable import PluginRailTokenTrend

@Suite("TokenCountFormat")
struct TokenCountFormatTests {
    @Test("values below 1000 are returned as-is")
    func smallValues() {
        #expect(TokenCountFormat.compact(0) == "0")
        #expect(TokenCountFormat.compact(1) == "1")
        #expect(TokenCountFormat.compact(999) == "999")
    }

    @Test("K suffix for thousands")
    func thousands() {
        #expect(TokenCountFormat.compact(1_000) == "1K")
        #expect(TokenCountFormat.compact(12_345) == "12.3K")
        #expect(TokenCountFormat.compact(150_000) == "150K")
    }

    @Test("M suffix for millions")
    func millions() {
        #expect(TokenCountFormat.compact(1_000_000) == "1M")
        #expect(TokenCountFormat.compact(43_982_407) == "44M")
        #expect(TokenCountFormat.compact(125_000_000) == "125M")
    }

    @Test("B suffix for billions")
    func billions() {
        #expect(TokenCountFormat.compact(1_000_000_000) == "1B")
    }

    @Test("rounding across magnitude boundary promotes to larger unit")
    func roundingPromotion() {
        // 999_999 rounds to 1000K → promoted to 1M
        #expect(TokenCountFormat.compact(999_999) == "1M")
    }
}
