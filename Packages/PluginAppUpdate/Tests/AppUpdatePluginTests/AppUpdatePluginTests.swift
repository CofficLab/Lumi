import AppUpdatePlugin
import Foundation
import Testing

@Suite("App update V2 host bootstrap")
@MainActor
struct AppUpdatePluginTests {
    @Test("retains the legacy check-for-updates notification name")
    func keepsNotificationName() {
        #expect(Notification.Name.checkForUpdates.rawValue == "checkForUpdates")
    }

    @Test("preserves architecture-specific feed paths")
    func keepsFeedPaths() {
        #expect(UpdateFeedURLProvider.primary(forArchitecture: "arm64").lastPathComponent == "appcast-arm64.xml")
        #expect(UpdateFeedURLProvider.fallback(forArchitecture: "x86_64").lastPathComponent == "appcast-x86_64.xml")
    }
}
