import AppUpdatePlugin
import Foundation
import ProviderAppUpdate
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

    @Test("uses the domestic primary feed and preserves GitHub fallback")
    func keepsFeedHosts() {
        #expect(UpdateFeedURLProvider.primary(forArchitecture: "arm64").host == "s.kuaiyizhi.cn")
        #expect(UpdateFeedURLProvider.fallback(forArchitecture: "x86_64").host == "github.com")
    }

    @Test("keeps preview feeds isolated from stable feeds")
    func keepsPreviewFeedsIsolated() {
        let previewPrimaryArm64 = UpdateFeedURLProvider.primary(for: .preview, architecture: "arm64")
        let previewPrimaryX86 = UpdateFeedURLProvider.primary(for: .preview, architecture: "x86_64")
        let previewFallback = UpdateFeedURLProvider.fallback(for: .preview, architecture: "x86_64")

        #expect(previewPrimaryArm64.path == "/lumi/pre/appcast-pre-arm64.xml")
        #expect(previewPrimaryX86.path == "/lumi/pre/appcast-pre-x86_64.xml")
        #expect(previewFallback.host == "raw.githubusercontent.com")
        #expect(previewFallback.path == "/CofficLab/Lumi/pre/appcast-pre-x86_64.xml")
    }
}
