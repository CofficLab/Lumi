import Foundation
import Testing
import LumiCoreKit
import SwiftData
@testable import PluginAppManager

@MainActor
struct PluginAppManagerTests {
    @Test
    func pluginMetadataIsStable() {
        #expect(AppManagerPlugin.id == "AppManager")
        #expect(AppManagerPlugin.navigationId == "app_manager")
        #expect(AppManagerPlugin.displayName.isEmpty == false)
        #expect(AppManagerPlugin.description.isEmpty == false)
        #expect(AppManagerPlugin.iconName == "apps.ipad")
        #expect(AppManagerPlugin.category == .system)
        #expect(AppManagerPlugin.order == 40)
        #expect(AppManagerPlugin.policy == .alwaysOn)
        #expect(AppManagerPlugin.shared.instanceLabel == AppManagerPlugin.id)
    }

    @Test
    func viewContainerContributionIsAvailable() {
        let item = AppManagerPlugin.shared.addViewContainer()
        #expect(item?.id == AppManagerPlugin.id)
        #expect(item?.title == AppManagerPlugin.displayName)
        #expect(item?.icon == AppManagerPlugin.iconName)
    }

    @Test
    func localizationCatalogIsPackaged() {
        #expect(PluginAppManagerLocalization.bundle.url(forResource: "AppManager", withExtension: "xcstrings") != nil)
        #expect(PluginAppManagerLocalization.string("App Manager").isEmpty == false)
    }

    @Test
    func directoryURLSupportsSpacesAndSpecialCharacters() {
        let url = AppService.directoryURL(forPath: "/tmp/Lumi App Manager/#Test Folder")

        #expect(url.isFileURL)
        #expect(url.path == "/tmp/Lumi App Manager/#Test Folder")
        #expect(url.absoluteString.contains("Lumi%20App%20Manager"))
        #expect(url.absoluteString.contains("%23Test%20Folder"))
    }

    @Test
    func appCleanerReturnsNoRelatedFilesWhenLibraryDirectoryIsUnavailable() {
        let helper = AppCleanerHelper(libraryDirectoryURL: nil)
        let app = AppModel(
            bundleURL: URL(fileURLWithPath: "/Applications/Test.app"),
            name: "Test",
            identifier: "com.example.test",
            version: "1.0",
            iconFileName: nil,
            size: 0
        )

        #expect(helper.scanRelatedFiles(for: app).isEmpty)
    }

    @Test
    func cacheStoreRecoversWhenDatabaseDirectoryIsBlocked() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("app-manager-cache-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let blockedDirectory = root.appendingPathComponent("AppManagerPlugin", isDirectory: true)
        try "not a directory".write(to: blockedDirectory, atomically: true, encoding: .utf8)

        let container = CacheManager.makeContainer(databaseRootURL: root)
        let context = ModelContext(container)
        let item = AppCacheItem(
            bundlePath: "/Applications/Test.app",
            lastModified: 1,
            name: "Test",
            identifier: "com.example.test",
            version: "1.0",
            iconFileName: nil,
            size: 42
        )

        context.insert(item)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<AppCacheItem>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.bundlePath == "/Applications/Test.app")
    }
}
