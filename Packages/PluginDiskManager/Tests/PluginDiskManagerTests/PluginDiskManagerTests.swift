import Testing
import Foundation
@testable import PluginDiskManager

@MainActor
struct PluginDiskManagerTests {
    @Test
    func pluginMetadataIsStable() {
        #expect(DiskManagerPlugin().id == "com.coffic.lumi.plugin.disk-manager")
        #expect(DiskManagerPlugin().name.isEmpty == false)
        #expect(DiskManagerPlugin().order == 250)
        #expect(DiskManagerPlugin().metadata.policy == .disabledByDefault)
        #expect(DiskManagerPlugin().metadata.stage == .preview)
    }

    @Test
    func agentToolsContributionIsAvailable() {
        #expect(DiskManagerPlugin.agentTools.count == 10)
        #expect(DiskManagerPlugin.agentTools.allSatisfy { !$0.name.isEmpty })
    }

    @Test
    func railTabIDIsStable() {
        #expect(DiskManagerPlugin.railTabID == "com.coffic.lumi.plugin.disk-manager.categories")
    }

    @Test
    func localizationCatalogIsPackaged() {
        #expect(PluginDiskManagerLocalization.bundle.url(forResource: "Localizable", withExtension: "xcstrings") != nil)
        #expect(PluginDiskManagerLocalization.string("Disk Manager").isEmpty == false)
    }

    @Test
    func scanURLAcceptsUnescapedFileURL() {
        #expect(
            DiskManagerViewModel.scanURL(from: "file:///tmp/project/My Folder").path
                == "/tmp/project/My Folder"
        )
    }

    @Test
    func scanURLAcceptsLocalPathAndTilde() {
        #expect(DiskManagerViewModel.scanURL(from: " /tmp/project ").path == "/tmp/project")
        #expect(
            DiskManagerViewModel.scanURL(from: "~/Downloads").path
                == FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads").path
        )
    }
}
