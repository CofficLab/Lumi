import Testing
import Foundation
import KernelLumi
@testable import DiskManagerPlugin

@MainActor
struct PluginDiskManagerTests {
    @Test
    func pluginMetadataIsStable() {
        #expect(DiskManagerPlugin().id == "com.coffic.lumi.plugin.disk-manager")
        #expect(DiskManagerPlugin().name.isEmpty == false)
        #expect(DiskManagerPlugin().order == 250)
        #expect(DiskManagerPlugin().policy == .optIn)
        #expect(DiskManagerPlugin().stage == .beta)
    }

    @Test
    func viewContainerContributionIsAvailable() throws {
        let items = DiskManagerPlugin().viewContainers(kernel: KernelLumi())
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
