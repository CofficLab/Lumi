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
}
