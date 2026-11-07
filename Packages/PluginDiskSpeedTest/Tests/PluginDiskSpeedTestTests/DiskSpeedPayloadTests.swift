import Foundation
import Testing
@testable import PluginDiskSpeedTest

@Suite("DiskSpeedPayload")
struct DiskSpeedPayloadTests {

    @Test("running payload has no measured speeds")
    func runningPayloadHasNoSpeeds() {
        let payload = DiskSpeedPayload.running(directory: "/tmp")
        #expect(payload.phase == .running)
        #expect(payload.readBytesPerSecond == nil)
        #expect(payload.writeBytesPerSecond == nil)
        #expect(!payload.isTerminal)
    }

    @Test("failed payload keeps the reason")
    func failedPayloadKeepsReason() {
        let payload = DiskSpeedPayload.failed(directory: "/tmp", reason: "disk full")
        #expect(payload.phase == .failed)
        #expect(payload.failureReason == "disk full")
        #expect(payload.isTerminal)
    }

    @Test("speed formatting picks the right unit")
    func speedFormattingPicksUnit() {
        #expect(DiskSpeedPayload.formattedSpeed(2_000_000_000) == "2.00 GB/s")
        #expect(DiskSpeedPayload.formattedSpeed(1_500_000) == "1.5 MB/s")
        #expect(DiskSpeedPayload.formattedSpeed(2_000) == "2.0 KB/s")
        #expect(DiskSpeedPayload.formattedSpeed(500) == "500 B/s")
    }

    @Test("non-positive or nil speed formats to nil")
    func invalidSpeedFormatsToNil() {
        #expect(DiskSpeedPayload.formattedSpeed(nil) == nil)
        #expect(DiskSpeedPayload.formattedSpeed(0) == nil)
        #expect(DiskSpeedPayload.formattedSpeed(-1) == nil)
    }

    @Test("byte formatting picks the right unit")
    func byteFormattingPicksUnit() {
        #expect(DiskSpeedPayload.formattedBytes(0) == "0 B")
        #expect(DiskSpeedPayload.formattedBytes(512) == "512 B")
        #expect(DiskSpeedPayload.formattedBytes(1_500_000) == "1.5 MB")
        #expect(DiskSpeedPayload.formattedBytes(2_000_000_000) == "2.00 GB")
    }
}
