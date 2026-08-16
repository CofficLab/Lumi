import Foundation
import Testing
@testable import OpenInKit

extension WorkspaceDependentTests {
    @Suite("OpenAppType full mapping")
    struct OpenAppTypeMappingTests {

    @Test("every case has a non-empty bundle id except auto/browser/finder")
    func bundleIdCompleteness() {
        for type in OpenAppType.allCases {
            switch type {
            case .auto, .browser, .finder:
                #expect(type.bundleId == nil)
            default:
                #expect(type.bundleId != nil && !type.bundleId!.isEmpty)
            }
        }
    }

    @Test("every case has a non-empty icon and display name")
    func metadataCompleteness() {
        for type in OpenAppType.allCases {
            #expect(!type.icon.isEmpty)
            #expect(!type.displayName.isEmpty)
        }
    }

    @Test("browser and finder are always considered installed")
    func alwaysInstalled() {
        #expect(OpenAppType.auto.isInstalled)
        #expect(OpenAppType.browser.isInstalled)
    }

    @Test("openIn auto routes by URL kind")
    func openInAutoRouting() {
        let mock = MockWorkspace()
        WorkspaceEnvironment.workspace = mock
        defer { WorkspaceEnvironment.workspace = SystemWorkspaceOpener.shared }

        let web = URL(string: "https://example.com")!
        web.openIn(.auto)
        #expect(mock.openedURLs == [web])

        let file = URL(fileURLWithPath: "/tmp/file.txt")
        file.openIn(.auto)
        #expect(mock.selectedInFinder == [file])
    }

    @Test("openIn browser routes to workspace.open")
    func openInBrowserRouting() {
        let mock = MockWorkspace()
        WorkspaceEnvironment.workspace = mock
        defer { WorkspaceEnvironment.workspace = SystemWorkspaceOpener.shared }

        let url = URL(fileURLWithPath: "/tmp/page.html")
        url.openIn(.browser)
        #expect(mock.openedURLs == [url])
    }

    @Test("openIn finder routes to Finder selection")
    func openInFinderRouting() {
        let mock = MockWorkspace()
        WorkspaceEnvironment.workspace = mock
        defer { WorkspaceEnvironment.workspace = SystemWorkspaceOpener.shared }

        let url = URL(fileURLWithPath: "/tmp/file.txt")
        url.openIn(.finder)
        #expect(mock.selectedInFinder == [url])
    }

    @Test("openFolder opens parent directory for file URLs")
    func openFolderForFile() {
        let mock = MockWorkspace()
        WorkspaceEnvironment.workspace = mock
        defer { WorkspaceEnvironment.workspace = SystemWorkspaceOpener.shared }

        let file = URL(fileURLWithPath: "/tmp/project/readme.md")
        file.openFolder()
        #expect(mock.openedURLs == [URL(fileURLWithPath: "/tmp/project/")])
    }

    @Test("openFolder opens the directory itself")
    func openFolderForDirectory() {
        let mock = MockWorkspace()
        WorkspaceEnvironment.workspace = mock
        defer { WorkspaceEnvironment.workspace = SystemWorkspaceOpener.shared }

        let folder = URL(fileURLWithPath: "/tmp/project/", isDirectory: true)
        folder.openFolder()
        #expect(mock.openedURLs == [folder])
    }

    @Test("non-auto icon and displayName ignore URL")
    func nonAutoMetadataIgnoresURL() {
        let web = URL(string: "https://example.com")!
        #expect(OpenAppType.xcode.icon(for: web) == OpenAppType.xcode.icon)
        #expect(OpenAppType.terminal.displayName(for: web) == OpenAppType.terminal.displayName)
    }

    @Test("raw value round trip")
    func rawValueRoundTrip() {
        for type in OpenAppType.allCases {
            #expect(OpenAppType(rawValue: type.rawValue) == type)
        }
    }
    }
}
