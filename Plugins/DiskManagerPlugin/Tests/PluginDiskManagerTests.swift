import Testing
import Foundation
import LumiKernel
@testable import DiskManagerPlugin

@MainActor
struct PluginDiskManagerTests {
    @Test
    func pluginMetadataIsStable() {
        #expect(DiskManagerPlugin().id == "com.coffic.lumi.plugin.disk-manager")
        #expect(DiskManagerPlugin().name.isEmpty == false)
        #expect(DiskManagerPlugin().category == .system)
        #expect(DiskManagerPlugin().order == 44)
        #expect(DiskManagerPlugin().policy == .optIn)
    }

    @Test
    func viewContainerContributionIsAvailable() throws {
        let items = DiskManagerPlugin.viewContainers(
            lumiCore: LumiPluginContext(activeSectionID: "workspace", activeSectionTitle: "Workspace")
        )
        let item = try #require(items.first)
        #expect(item.id == DiskManagerPlugin().id)
        #expect(item.title == DiskManagerPlugin().name)
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
