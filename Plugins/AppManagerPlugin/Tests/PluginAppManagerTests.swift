import Foundation
import Testing
import LumiKernel
import SwiftData
@testable import AppManagerPlugin

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
        #expect(AppManagerPlugin.policy == .disabled)
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

    @Test
    func cacheManagerReportsPersistenceResults() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("app-manager-cache-manager-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = CacheManager(databaseRootURL: root)
        let bundleURL = root.appendingPathComponent("Test.app", isDirectory: true)
        let modifiedAt = Date()
        let app = AppModel(
            bundleURL: bundleURL,
            name: "Test",
            identifier: "com.example.test",
            version: "1.0",
            iconFileName: nil,
            size: 0
        )

        let updated = await manager.updateCache(for: app, size: 42, modificationDate: modifiedAt)
        let cached = await manager.getCachedApp(at: bundleURL.path, currentModificationDate: modifiedAt)
        let cleaned = await manager.cleanInvalidCache(keeping: [])
        let afterClean = await manager.getCachedApp(at: bundleURL.path, currentModificationDate: modifiedAt)
        let cleared = await manager.clearAll()

        #expect(updated)
        #expect(cached?.name == "Test")
        #expect(cached?.size == 42)
        #expect(cleaned)
        #expect(afterClean == nil)
        #expect(cleared)
    }

    @Test
    func cancelledScanDoesNotClearLoadingForNewerScan() async throws {
        let staleApp = Self.app(path: "/Applications/Stale.app", name: "Stale", size: 1)
        let freshApp = Self.app(path: "/Applications/Fresh.app", name: "Fresh", size: 1)
        let service = FakeAppManagerService(results: [
            false: (delay: 80_000_000, apps: [staleApp]),
            true: (delay: 220_000_000, apps: [freshApp]),
        ])
        let viewModel = AppManagerViewModel(appService: service)

        let firstScan = Task {
            await viewModel.scanApps(force: false)
        }
        try await Task.sleep(nanoseconds: 20_000_000)
        let secondScan = Task {
            await viewModel.scanApps(force: true)
        }

        try await Task.sleep(nanoseconds: 120_000_000)
        #expect(viewModel.isLoading)
        #expect(viewModel.installedApps.isEmpty)

        await firstScan.value
        await secondScan.value

        #expect(viewModel.isLoading == false)
        #expect(viewModel.installedApps.map(\.displayName) == ["Fresh"])
    }

    private static func app(path: String, name: String, size: Int64) -> AppModel {
        AppModel(
            bundleURL: URL(fileURLWithPath: path),
            name: name,
            identifier: "com.example.\(name.lowercased())",
            version: "1.0",
            iconFileName: nil,
            size: size
        )
    }
}

private final class FakeAppManagerService: AppManagerServicing, @unchecked Sendable {
    let results: [Bool: (delay: UInt64, apps: [AppModel])]

    init(results: [Bool: (delay: UInt64, apps: [AppModel])]) {
        self.results = results
    }

    func scanInstalledApps(force: Bool) async -> [AppModel] {
        if let result = results[force] {
            try? await Task.sleep(nanoseconds: result.delay)
            return result.apps
        }
        return []
    }

    func calculateAppSize(for app: AppModel) async -> Int64 {
        app.size
    }

    func scanRelatedFiles(for app: AppModel) async -> [RelatedFile] {
        []
    }

    func deleteFiles(_ files: [RelatedFile]) async throws {}

    func saveCache() async {}

    func revealInFinder(_ app: AppModel) {}

    func openApp(_ app: AppModel) {}

    func getAppInfo(_ app: AppModel) -> String {
        app.displayName
    }
}
