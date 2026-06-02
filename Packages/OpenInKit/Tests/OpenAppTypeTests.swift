import Foundation
import Testing
@testable import OpenInKit

@Suite("OpenAppType", .serialized)
struct OpenAppTypeTests {

    @Test("bundle identifiers match MagicKit AppRegistry")
    func bundleIds() {
        #expect(OpenAppType.xcode.bundleId == "com.apple.dt.Xcode")
        #expect(OpenAppType.cursor.bundleId == "com.todesktop.230313mzl4w4u92")
        #expect(OpenAppType.antigravity.bundleId == "com.google.antigravity")
        #expect(OpenAppType.githubDesktop.bundleId == "com.github.GitHubClient")
        #expect(OpenAppType.auto.bundleId == nil)
        #expect(OpenAppType.browser.bundleId == nil)
    }

    @Test("auto icon and title depend on URL kind")
    func autoMetadataForURL() {
        let file = URL(fileURLWithPath: "/tmp/project")
        let web = URL(string: "https://example.com")!

        #expect(OpenAppType.auto.icon(for: file) == "arrow.forward.circle")
        #expect(OpenAppType.auto.icon(for: web) == "safari")
        #expect(OpenAppType.auto.displayName(for: file) == "在访达中显示")
        #expect(OpenAppType.auto.displayName(for: web) == "在浏览器中打开")
    }

    @Test("isInstalled uses workspace lookup")
    func isInstalledUsesWorkspace() {
        let mock = MockWorkspace()
        mock.applicationURLs["com.apple.dt.Xcode"] = URL(fileURLWithPath: "/Applications/Xcode.app")
        WorkspaceEnvironment.workspace = mock

        #expect(OpenAppType.xcode.isInstalled)
        #expect(!OpenAppType.cursor.isInstalled)

        WorkspaceEnvironment.workspace = SystemWorkspaceOpener.shared
    }

    #if os(macOS)
    @Test("realIcon resolves installed app from workspace")
    func realIconUsesWorkspace() {
        let mock = MockWorkspace()
        mock.applicationURLs["com.todesktop.230313mzl4w4u92"] = URL(fileURLWithPath: "/Applications/Cursor.app")
        WorkspaceEnvironment.workspace = mock

        let icon = OpenAppType.cursor.realIcon()
        #expect(icon != nil)

        WorkspaceEnvironment.workspace = SystemWorkspaceOpener.shared
    }

    @Test("realIcon returns nil when app is not installed")
    func realIconMissingApp() {
        let mock = MockWorkspace()
        WorkspaceEnvironment.workspace = mock

        #expect(OpenAppType.cursor.realIcon() == nil)

        WorkspaceEnvironment.workspace = SystemWorkspaceOpener.shared
    }
    #endif
}
