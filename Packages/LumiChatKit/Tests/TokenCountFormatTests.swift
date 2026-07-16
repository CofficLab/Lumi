import Foundation
import Testing
@testable import LumiChatKit

@Suite struct TokenCountFormatTests {

    // MARK: - tps

    @Test func tpsHighPrecisionForLargeValues() {
        #expect(TokenCountFormat.tps(150) == "150 t/s")
        #expect(TokenCountFormat.tps(100) == "100 t/s")
    }

    @Test func tpsOneDecimalForMidRange() {
        #expect(TokenCountFormat.tps(50) == "50.0 t/s")
        #expect(TokenCountFormat.tps(10) == "10.0 t/s")
    }

    @Test func tpsTwoDecimalsForSmallValues() {
        #expect(TokenCountFormat.tps(9) == "9.00 t/s")
        #expect(TokenCountFormat.tps(0) == "0.00 t/s")
    }

    // MARK: - contextSize

    @Test func contextSizeMillions() {
        #expect(TokenCountFormat.contextSize(1_000_000) == "1M")
        #expect(TokenCountFormat.contextSize(2_500_000) == "2.5M")
    }

    @Test func contextSizeThousands() {
        #expect(TokenCountFormat.contextSize(1_000) == "1K")
        // K tier always rounds to whole (no decimal), unlike M tier.
        #expect(TokenCountFormat.contextSize(1_500) == "2K")
    }

    // MARK: - tokenCount (usage)

    @Test func tokenCountMillions() {
        #expect(TokenCountFormat.tokenCount(1_000_000) == "1M")
        #expect(TokenCountFormat.tokenCount(3_400_000) == "3.4M")
    }

    @Test func tokenCountThousandsKeepsOneDecimal() {
        #expect(TokenCountFormat.tokenCount(1_000) == "1K")
        #expect(TokenCountFormat.tokenCount(1_234) == "1.2K")
        #expect(TokenCountFormat.tokenCount(12_300) == "12.3K")
    }

    @Test func tokenCountSmall() {
        #expect(TokenCountFormat.tokenCount(999) == "999")
        #expect(TokenCountFormat.tokenCount(0) == "0")
    }
}
