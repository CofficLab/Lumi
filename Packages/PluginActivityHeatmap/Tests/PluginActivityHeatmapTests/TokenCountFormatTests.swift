import Foundation
import Testing
@testable import PluginActivityHeatmap

@Suite("Token count formatting")
struct TokenCountFormatTests {
    @Test("keeps values below one thousand as-is")
    func keepsSmallValues() {
        #expect(TokenCountFormat.compact(0) == "0")
        #expect(TokenCountFormat.compact(999) == "999")
    }

    @Test("compacts thousands with one decimal below one hundred")
    func compactsThousands() {
        #expect(TokenCountFormat.compact(1_000) == "1K")
        #expect(TokenCountFormat.compact(12_345) == "12.3K")
        #expect(TokenCountFormat.compact(150_000) == "150K")
    }

    @Test("compacts millions with one decimal below one hundred")
    func compactsMillions() {
        #expect(TokenCountFormat.compact(1_000_000) == "1M")
        #expect(TokenCountFormat.compact(43_982_407) == "44M")
        #expect(TokenCountFormat.compact(125_000_000) == "125M")
    }

    @Test("compacts billions")
    func compactsBillions() {
        #expect(TokenCountFormat.compact(1_000_000_000) == "1B")
        #expect(TokenCountFormat.compact(2_450_000_000) == "2.5B")
    }

    @Test("promotes to a larger unit when rounding crosses a magnitude")
    func promotesAcrossMagnitude() {
        #expect(TokenCountFormat.compact(999_999) == "1M")
        #expect(TokenCountFormat.compact(999_999_999) == "1B")
    }
}
