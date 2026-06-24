import Testing
import Foundation
@testable import NetworkManagerPlugin

/// Unit tests for the network speed/byte formatting helpers.
@Suite struct SpeedFormatterTests {

    @Test func formatsGigabytesPerSecond() {
        // 1 GiB/s in bytes
        let bps = 1024.0 * 1024 * 1024
        #expect(SpeedFormatter.formatForStatusBar(bps) == "1.0GB/s")
    }

    @Test func formatsMegabytesPerSecond() {
        let bps = 1024.0 * 1024 * 2.5
        #expect(SpeedFormatter.formatForStatusBar(bps) == "2.5MB/s")
    }

    @Test func formatsKilobytesPerSecond() {
        let bps = 1024.0 * 500
        #expect(SpeedFormatter.formatForStatusBar(bps) == "500KB/s")
    }

    @Test func formatsBytesPerSecond() {
        #expect(SpeedFormatter.formatForStatusBar(512) == "512B/s")
        #expect(SpeedFormatter.formatForStatusBar(0) == "0B/s")
    }

    @Test func gigabyteThresholdIsInclusive() {
        // Exactly 1 GB (decimal) — but formatter uses 1024 base, so use 1 GiB.
        let oneGib = 1024.0 * 1024 * 1024
        #expect(SpeedFormatter.formatForStatusBar(oneGib).hasSuffix("GB/s"))
    }
}

@Suite struct DoubleNetworkSpeedFormatterTests {

    @Test func zeroSpeedDisplaysZeroKB() {
        #expect((0.0).formattedNetworkSpeed() == "0 KB/s")
    }

    @Test func nonzeroSpeedAppendsPerSecond() {
        let result = (1024.0 * 500).formattedNetworkSpeed()
        #expect(result.hasSuffix("/s"))
        #expect(result.contains("KB"))
    }

    @Test func zeroBytesDisplaysZeroKB() {
        #expect((0.0).formattedBytes() == "0 KB")
    }

    @Test func nonzeroBytesNoPerSecondSuffix() {
        let result = (1024.0 * 1024).formattedBytes()
        #expect(!result.hasSuffix("/s"))
        #expect(result.contains("MB"))
    }
}

@Suite struct Int64NetworkSpeedFormatterTests {

    @Test func zeroSpeedDisplaysZeroKB() {
        #expect(Int64(0).formattedNetworkSpeed() == "0 KB/s")
    }

    @Test func nonzeroSpeedAppendsPerSecond() {
        let result = Int64(1024 * 500).formattedNetworkSpeed()
        #expect(result.hasSuffix("/s"))
        #expect(result.contains("KB"))
    }

    @Test func zeroBytesDisplaysZeroKB() {
        #expect(Int64(0).formattedBytes() == "0 KB")
    }

    @Test func nonzeroBytesNoPerSecondSuffix() {
        let result = Int64(1024 * 1024).formattedBytes()
        #expect(!result.hasSuffix("/s"))
        #expect(result.contains("MB"))
    }
}
