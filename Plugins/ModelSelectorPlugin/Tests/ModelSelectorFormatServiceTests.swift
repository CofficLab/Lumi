import Testing
import Foundation
import LumiCoreKit
import LumiCoreKit
@testable import ModelSelectorPlugin

/// Unit tests for `ModelSelectorFormatService` (pure formatting) and the
/// computed averages on `ModelPerformanceStats`.
@Suite struct ModelSelectorFormatServiceTests {

    // MARK: - tps

    @Test func tpsHighPrecisionForLargeValues() {
        #expect(ModelSelectorFormatService.tps(150) == "150 t/s")
        #expect(ModelSelectorFormatService.tps(100) == "100 t/s")
    }

    @Test func tpsOneDecimalForMidRange() {
        #expect(ModelSelectorFormatService.tps(50) == "50.0 t/s")
        #expect(ModelSelectorFormatService.tps(10) == "10.0 t/s")
    }

    @Test func tpsTwoDecimalsForSmallValues() {
        #expect(ModelSelectorFormatService.tps(9) == "9.00 t/s")
        #expect(ModelSelectorFormatService.tps(9.99) == "9.99 t/s")
    }

    @Test func tpsZero() {
        #expect(ModelSelectorFormatService.tps(0) == "0.00 t/s")
    }

    @Test func tpsBoundaryBetweenTiers() {
        // 99.99 rounds within the mid tier; 100 is the high tier.
        #expect(ModelSelectorFormatService.tps(99.99).hasSuffix("t/s"))
        #expect(!ModelSelectorFormatService.tps(99.99).contains("99.99"))
    }
}

@Suite struct ModelSelectorFormatServiceContextSizeTests {

    @Test func contextSizeMillions() {
        #expect(ModelSelectorFormatService.contextSize(1_000_000) == "1M")
        #expect(ModelSelectorFormatService.contextSize(2_000_000) == "2M")
        #expect(ModelSelectorFormatService.contextSize(2_500_000) == "2.5M")
    }

    @Test func contextSizeThousands() {
        #expect(ModelSelectorFormatService.contextSize(1_000) == "1K")
        // Documented: K tier always rounds to whole (no decimal), unlike M tier.
        #expect(ModelSelectorFormatService.contextSize(1_500) == "2K")
        #expect(ModelSelectorFormatService.contextSize(1_499) == "1K")
    }

    @Test func contextSizeSmall() {
        #expect(ModelSelectorFormatService.contextSize(999) == "999")
        #expect(ModelSelectorFormatService.contextSize(0) == "0")
    }
}

@Suite struct ModelSelectorFormatServiceTokenCountTests {

    @Test func tokenCountMillions() {
        #expect(ModelSelectorFormatService.tokenCount(1_000_000) == "1M")
        #expect(ModelSelectorFormatService.tokenCount(3_400_000) == "3.4M")
    }

    @Test func tokenCountThousandsKeepsOneDecimal() {
        // Unlike contextSize, the K tier keeps one decimal for usage.
        #expect(ModelSelectorFormatService.tokenCount(1_000) == "1K")
        #expect(ModelSelectorFormatService.tokenCount(1_234) == "1.2K")
        #expect(ModelSelectorFormatService.tokenCount(12_300) == "12.3K")
    }

    @Test func tokenCountSmall() {
        #expect(ModelSelectorFormatService.tokenCount(999) == "999")
        #expect(ModelSelectorFormatService.tokenCount(0) == "0")
    }
}

@Suite struct ModelPerformanceStatsTests {

    @Test func avgLatencyGuardsZeroSamples() {
        var stats = ModelPerformanceStats(providerID: "p", modelName: "m")
        #expect(stats.avgLatency == 0)
        stats.sampleCount = 2
        stats.totalLatency = 500
        #expect(stats.avgLatency == 250)
    }

    @Test func avgTTFTGuardsZeroCount() {
        var stats = ModelPerformanceStats(providerID: "p", modelName: "m")
        #expect(stats.avgTTFT == 0)
        stats.ttftCount = 4
        stats.totalTTFT = 1200
        #expect(stats.avgTTFT == 300)
    }

    @Test func avgTPSRequiresStreamingDuration() {
        var stats = ModelPerformanceStats(providerID: "p", modelName: "m")
        stats.totalOutputTokens = 1000
        // No streaming duration → TPS is 0.
        #expect(stats.avgTPS == 0)

        stats.totalStreamingDuration = 10_000  // 10 seconds
        stats.streamingDurationCount = 1
        // 1000 tokens / 10s = 100 t/s
        #expect(stats.avgTPS == 100)
    }

    @Test func avgTPSGuardsZeroDurationTotal() {
        var stats = ModelPerformanceStats(providerID: "p", modelName: "m")
        stats.totalOutputTokens = 100
        stats.streamingDurationCount = 1
        stats.totalStreamingDuration = 0  // guard: zero total duration
        #expect(stats.avgTPS == 0)
    }
}
