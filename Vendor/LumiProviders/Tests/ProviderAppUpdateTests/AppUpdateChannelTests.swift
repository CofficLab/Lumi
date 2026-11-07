import Foundation
import Testing
@testable import ProviderAppUpdate

@Suite("ProviderAppUpdate")
struct AppUpdateChannelTests {
    @Test("exposes stable and preview channels")
    func exposesChannels() {
        #expect(AppUpdateChannel.allCases == [.stable, .preview])
        #expect(AppUpdateChannel.stable.rawValue == "stable")
        #expect(AppUpdateChannel.preview.rawValue == "preview")
    }

    @Test("there are exactly two release tracks")
    func hasTwoChannels() {
        #expect(AppUpdateChannel.allCases.count == 2)
    }

    @Test("raw values reconstruct each channel via init(rawValue:)")
    func rawValueRoundtrip() {
        #expect(AppUpdateChannel(rawValue: "stable") == .stable)
        #expect(AppUpdateChannel(rawValue: "preview") == .preview)
        #expect(AppUpdateChannel(rawValue: "beta") == nil)
        #expect(AppUpdateChannel(rawValue: "") == nil)
    }

    @Test("channels are Codable")
    func channelCodableRoundtrip() throws {
        for channel in AppUpdateChannel.allCases {
            let data = try JSONEncoder().encode(channel)
            let decoded = try JSONDecoder().decode(AppUpdateChannel.self, from: data)
            #expect(decoded == channel)
        }
    }

    @Test("encoded raw value matches the string enum representation")
    func encodedRawValueMatches() throws {
        let stableData = try JSONEncoder().encode(AppUpdateChannel.stable)
        let stableJSON = String(data: stableData, encoding: .utf8)
        #expect(stableJSON == "\"stable\"")

        let previewData = try JSONEncoder().encode(AppUpdateChannel.preview)
        let previewJSON = String(data: previewData, encoding: .utf8)
        #expect(previewJSON == "\"preview\"")
    }

    @Test("channels are Hashable and usable as dictionary keys")
    func channelHashable() {
        var counts: [AppUpdateChannel: Int] = [:]
        for channel in AppUpdateChannel.allCases {
            counts[channel, default: 0] += 1
        }
        #expect(counts[.stable] == 1)
        #expect(counts[.preview] == 1)

        let set: Set<AppUpdateChannel> = [.stable, .preview, .stable]
        #expect(set.count == 2)
    }

    @Test("user defaults key is the expected persistent identifier")
    func userDefaultsKeyIsStable() {
        #expect(AppUpdateChannel.userDefaultsKey == "com.coffic.lumi.appUpdateChannel")
    }
}
