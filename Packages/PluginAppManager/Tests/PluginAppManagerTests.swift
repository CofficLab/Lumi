import Foundation
import Testing
import SwiftData
import KernelCore
import ProviderActivityBar
import ProviderChatSection
import ProviderRailView
@testable import AppManagerPlugin

@MainActor
struct PluginAppManagerTests {
    @Test
    func v2PluginStateIsStable() {
        #expect(AppManagerPluginSupport.railTabID == "app-manager.sidebar")
        #expect(AppManagerPlugin().id == "com.coffic.lumi.plugin.app-manager")
    }

    @Test
    func activatingPluginHidesChatSectionAndDeactivatingRestoresIt() throws {
        let kernel = KernelCoreContainer()
        let activity = DefaultActivityBarProviding()
        let chat = DefaultChatSectionProviding()
        let rail = DefaultRailViewProviding(visibleCategories: [.chat])
        try kernel.registerProvider((any ActivityBarProviding).self, activity)
        try kernel.registerProvider((any ChatSectionProviding).self, chat)
        try kernel.registerProvider((any RailViewProviding).self, rail)

        activity.addItems([ActivityBarItem(id: "chat.entry", title: "Chat", systemImage: "message")])

        try AppManagerPlugin().onBoot(kernel: kernel)

        #expect(activity.activeItemID == "chat.entry")

        activity.activateItem(id: "com.coffic.lumi.plugin.app-manager.entry")

        #expect(!chat.isVisible)
        #expect(rail.visibleCategories == [.system])
        #expect(rail.visibleTabID == AppManagerPluginSupport.railTabID)
        #expect(rail.activeTabID == AppManagerPluginSupport.railTabID)

        activity.activateItem(id: nil)

        #expect(chat.isVisible)
    }

    @Test
    func localizationCatalogIsPackaged() {
        // .xcstrings 会被编译进各语言的 .lproj/Localizable.strings，源文件不随包分发。
        let compiled = PluginAppManagerLocalization.bundle.path(
            forResource: "Localizable",
            ofType: "strings",
            inDirectory: nil
        ) ?? PluginAppManagerLocalization.bundle.path(
            forResource: "Localizable",
            ofType: "strings",
            inDirectory: "en.lproj"
        )
        #expect(compiled != nil)
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

        let container = CacheManager.makeContainer(pluginDataDirectory: blockedDirectory)
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

        let manager = CacheManager(pluginDataDirectory: root)
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

    @Test
    func untrustedBundleNameCannotEscapeApplicationSupport() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("app-manager-path-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let home = root.appendingPathComponent("home", isDirectory: true)
        let support = home.appendingPathComponent("Library/Application Support", isDirectory: true)
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        let innocentTarget = home.appendingPathComponent("Downloads/LumiAuditTarget", isDirectory: true)
        try FileManager.default.createDirectory(at: innocentTarget, withIntermediateDirectories: true)

        let appURL = try Self.makeApp(
            in: home.appendingPathComponent("Downloads", isDirectory: true),
            name: "Evil",
            bundleName: "../../Downloads/LumiAuditTarget",
            bundleIdentifier: "com.example.audit"
        )
        let app = AppModel(bundleURL: appURL)
        #expect(app.bundleName == "Evil")

        let files = await AppService(homeDirectory: home.path).scanRelatedFiles(for: app)

        #expect(!files.contains { $0.path == innocentTarget.path })
        #expect(files.allSatisfy { URL(fileURLWithPath: $0.path).standardizedFileURL.path.hasPrefix(support.path) == false })
    }

    @Test
    func emptyBundleNameDoesNotSelectApplicationSupportRoot() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("app-manager-empty-name-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let home = root.appendingPathComponent("home", isDirectory: true)
        let support = home.appendingPathComponent("Library/Application Support", isDirectory: true)
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)

        let appURL = try Self.makeApp(
            in: home.appendingPathComponent("Downloads", isDirectory: true),
            name: "Empty",
            bundleName: "",
            bundleIdentifier: "com.example.empty"
        )
        let app = AppModel(bundleURL: appURL)
        #expect(app.bundleName == "Empty")

        let files = await AppService(homeDirectory: home.path).scanRelatedFiles(for: app)

        let supportPath = support.standardizedFileURL.path
        #expect(!files.contains { URL(fileURLWithPath: $0.path).standardizedFileURL.path == supportPath })
    }

    @Test
    func pathContainmentRejectsEscapesAndDirectoryItself() {
        let root = "/tmp/LumiAppManagerRoot"
        #expect(AppService.isContained(path: "\(root)/Child", in: root))
        #expect(!AppService.isContained(path: "\(root)/../Elsewhere", in: root))
        #expect(!AppService.isContained(path: root, in: root))
        #expect(!AppService.isContained(path: "\(root)Extra/Child", in: root))
    }

    @Test
    func untrustedBundleIdentifierCannotEscapeLibrary() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("app-manager-bundle-id-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let home = root.appendingPathComponent("home", isDirectory: true)
        // 创建全部 Library 子目录，使 `../..` 能在文件系统层面解析。
        for lib in ["Application Support", "Caches", "Preferences", "Saved Application State",
                    "Containers", "Logs", "Cookies", "WebKit"] {
            try FileManager.default.createDirectory(
                at: home.appendingPathComponent("Library/\(lib)", isDirectory: true),
                withIntermediateDirectories: true
            )
        }
        // Library 之外的无辜目标：目录、plist、savedState 各一，分别对应策略 A/C/D。
        let documents = home.appendingPathComponent("Documents", isDirectory: true)
        let innocentDir = documents.appendingPathComponent("LumiAuditTarget", isDirectory: true)
        let innocentPlist = documents.appendingPathComponent("LumiAuditTarget.plist")
        let innocentState = documents.appendingPathComponent("LumiAuditTarget.savedState", isDirectory: true)
        try FileManager.default.createDirectory(at: innocentDir, withIntermediateDirectories: true)
        try "secret".write(to: innocentPlist, atomically: true, encoding: .utf8)
        try FileManager.default.createDirectory(at: innocentState, withIntermediateDirectories: true)

        let appURL = try Self.makeApp(
            in: home.appendingPathComponent("Downloads", isDirectory: true),
            name: "Evil",
            bundleName: "Evil",
            bundleIdentifier: "../../Documents/LumiAuditTarget"
        )
        let app = AppModel(bundleURL: appURL)
        #expect(app.bundleIdentifier == "../../Documents/LumiAuditTarget")

        let files = await AppService(homeDirectory: home.path).scanRelatedFiles(for: app)

        // 任何关联文件都不得落入 Library 之外的 Documents（#211）。
        let documentsPrefix = documents.standardizedFileURL.path + "/"
        #expect(!files.contains { URL(fileURLWithPath: $0.path).standardizedFileURL.path.hasPrefix(documentsPrefix) })
        #expect(!files.contains { $0.path == innocentDir.path })
        #expect(!files.contains { $0.path == innocentPlist.path })
        #expect(!files.contains { $0.path == innocentState.path })
        // 无辜目标必须原封不动（未被移入废纸篓）。
        #expect(FileManager.default.fileExists(atPath: innocentDir.path))
        #expect(FileManager.default.fileExists(atPath: innocentPlist.path))
        #expect(FileManager.default.fileExists(atPath: innocentState.path))
    }

    @Test
    func validBundleIdentifierStillMatchesLibraryFiles() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("app-manager-valid-id-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let home = root.appendingPathComponent("home", isDirectory: true)
        let support = home.appendingPathComponent("Library/Application Support", isDirectory: true)
        let preferences = home.appendingPathComponent("Library/Preferences", isDirectory: true)
        let savedState = home.appendingPathComponent("Library/Saved Application State", isDirectory: true)
        let supportDir = support.appendingPathComponent("com.example.app", isDirectory: true)
        let plistFile = preferences.appendingPathComponent("com.example.app.plist")
        let stateDir = savedState.appendingPathComponent("com.example.app.savedState", isDirectory: true)
        try FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: preferences, withIntermediateDirectories: true)
        try "prefs".write(to: plistFile, atomically: true, encoding: .utf8)
        try FileManager.default.createDirectory(at: stateDir, withIntermediateDirectories: true)

        let appURL = try Self.makeApp(
            in: home.appendingPathComponent("Downloads", isDirectory: true),
            name: "Good",
            bundleName: "Good",
            bundleIdentifier: "com.example.app"
        )
        let app = AppModel(bundleURL: appURL)

        let files = await AppService(homeDirectory: home.path).scanRelatedFiles(for: app)
        let paths = Set(files.map { URL(fileURLWithPath: $0.path).standardizedFileURL.path })

        // 合法 Bundle ID 仍须命中 Application Support / Preferences plist / Saved State。
        #expect(paths.contains(supportDir.standardizedFileURL.path))
        #expect(paths.contains(plistFile.standardizedFileURL.path))
        #expect(paths.contains(stateDir.standardizedFileURL.path))
    }

    // MARK: - 卸载归属保护（回归 #647）

    @Test
    func nameOnlySupportMatchIsNotOwnershipVerified() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("app-manager-ownership-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let home = root.appendingPathComponent("home", isDirectory: true)
        let support = home.appendingPathComponent("Library/Application Support", isDirectory: true)
        // 厂商 B 的数据目录，仅与厂商 A 的 CFBundleName 同名。
        let vendorBData = support.appendingPathComponent("Notes", isDirectory: true)
        try FileManager.default.createDirectory(at: vendorBData, withIntermediateDirectories: true)
        try "vendor-b-secret".write(to: vendorBData.appendingPathComponent("data.txt"), atomically: true, encoding: .utf8)

        // 厂商 A：Bundle ID 精确目录不存在，只有同名目录可匹配。
        let appURL = try Self.makeApp(
            in: home.appendingPathComponent("Downloads", isDirectory: true),
            name: "Notes",
            bundleName: "Notes",
            bundleIdentifier: "com.vendor-a.notes"
        )
        let app = AppModel(bundleURL: appURL)

        let files = await AppService(homeDirectory: home.path).scanRelatedFiles(for: app)

        // 同名目录仍被列出（供用户手动选择），但归属未确认。
        let nameMatch = try #require(files.first { $0.path == vendorBData.path })
        #expect(nameMatch.ownershipVerified == false)
        // App 本体归属始终确认。
        let appEntry = try #require(files.first { $0.type == .app })
        #expect(appEntry.ownershipVerified == true)
    }

    @Test
    func bundleIdSupportMatchIsOwnershipVerified() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("app-manager-ownership-id-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let home = root.appendingPathComponent("home", isDirectory: true)
        let support = home.appendingPathComponent("Library/Application Support", isDirectory: true)
        let preciseDir = support.appendingPathComponent("com.vendor-b.notes", isDirectory: true)
        let nameOnlyDir = support.appendingPathComponent("Notes", isDirectory: true)
        try FileManager.default.createDirectory(at: preciseDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: nameOnlyDir, withIntermediateDirectories: true)

        let appURL = try Self.makeApp(
            in: home.appendingPathComponent("Downloads", isDirectory: true),
            name: "Notes",
            bundleName: "Notes",
            bundleIdentifier: "com.vendor-b.notes"
        )
        let app = AppModel(bundleURL: appURL)

        let files = await AppService(homeDirectory: home.path).scanRelatedFiles(for: app)

        // 精确 Bundle ID 命中归属确认；同名目录不得再被当作关联文件。
        let precise = try #require(files.first { $0.path == preciseDir.path })
        #expect(precise.ownershipVerified == true)
        #expect(!files.contains { $0.path == nameOnlyDir.path })
    }

    @Test
    func defaultSelectionExcludesUnverifiedNameOnlyMatch() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("app-manager-ownership-select-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let home = root.appendingPathComponent("home", isDirectory: true)
        let support = home.appendingPathComponent("Library/Application Support", isDirectory: true)
        let vendorBData = support.appendingPathComponent("Notes", isDirectory: true)
        try FileManager.default.createDirectory(at: vendorBData, withIntermediateDirectories: true)

        let appURL = try Self.makeApp(
            in: home.appendingPathComponent("Downloads", isDirectory: true),
            name: "Notes",
            bundleName: "Notes",
            bundleIdentifier: "com.vendor-a.notes"
        )
        let app = AppModel(bundleURL: appURL)

        let viewModel = AppManagerViewModel(appService: AppService(homeDirectory: home.path))
        viewModel.selectedApp = app
        viewModel.scanRelatedFiles(for: app)
        try await Self.waitForScan(viewModel)

        let nameMatch = try #require(viewModel.relatedFiles.first { $0.path == vendorBData.path })
        let appEntry = try #require(viewModel.relatedFiles.first { $0.type == .app })
        // 默认勾选不得包含未确认归属的同名目录，但应包含 App 本体。
        #expect(!viewModel.selectedFileIds.contains(nameMatch.id))
        #expect(viewModel.selectedFileIds.contains(appEntry.id))
    }

    @Test
    func defaultSelectionIncludesVerifiedBundleIdMatch() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("app-manager-ownership-select-id-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let home = root.appendingPathComponent("home", isDirectory: true)
        let support = home.appendingPathComponent("Library/Application Support", isDirectory: true)
        let preciseDir = support.appendingPathComponent("com.vendor-b.notes", isDirectory: true)
        try FileManager.default.createDirectory(at: preciseDir, withIntermediateDirectories: true)

        let appURL = try Self.makeApp(
            in: home.appendingPathComponent("Downloads", isDirectory: true),
            name: "Notes",
            bundleName: "Notes",
            bundleIdentifier: "com.vendor-b.notes"
        )
        let app = AppModel(bundleURL: appURL)

        let viewModel = AppManagerViewModel(appService: AppService(homeDirectory: home.path))
        viewModel.selectedApp = app
        viewModel.scanRelatedFiles(for: app)
        try await Self.waitForScan(viewModel)

        let precise = try #require(viewModel.relatedFiles.first { $0.path == preciseDir.path })
        // 归属确认的精确匹配仍须默认勾选，过滤不能误伤合法关联文件。
        #expect(viewModel.selectedFileIds.contains(precise.id))
    }

    // MARK: - 无 Bundle ID 仍可卸载（回归 #794）

    @Test
    func nilBundleIdentifierStillListsAppItselfForUninstall() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("app-manager-no-id-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let home = root.appendingPathComponent("home", isDirectory: true)
        let support = home.appendingPathComponent("Library/Application Support", isDirectory: true)
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)

        let appURL = try Self.makeAppWithoutBundleID(
            in: home.appendingPathComponent("Downloads", isDirectory: true),
            name: "NoID",
            bundleName: "NoID"
        )
        let app = AppModel(bundleURL: appURL)
        #expect(app.bundleIdentifier == nil)

        let files = await AppService(homeDirectory: home.path).scanRelatedFiles(for: app)

        // 没有 Bundle ID 也必须列出 App 本体，否则卸载入口为空、无法删除（#794）。
        let appEntry = try #require(files.first { $0.type == .app })
        #expect(appEntry.path == appURL.path)
        #expect(appEntry.ownershipVerified == true)
        // 无 Bundle ID 时跳过依赖标识符的 Library 扫描，只剩 App 本体。
        #expect(files.count == 1)
    }

    @Test
    func nilBundleIdentifierAppIsSelectedForUninstallByDefault() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("app-manager-no-id-select-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let home = root.appendingPathComponent("home", isDirectory: true)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)

        let appURL = try Self.makeAppWithoutBundleID(
            in: home.appendingPathComponent("Downloads", isDirectory: true),
            name: "NoID",
            bundleName: "NoID"
        )
        let app = AppModel(bundleURL: appURL)
        #expect(app.bundleIdentifier == nil)

        let viewModel = AppManagerViewModel(appService: AppService(homeDirectory: home.path))
        viewModel.selectedApp = app
        viewModel.scanRelatedFiles(for: app)
        try await Self.waitForScan(viewModel)

        let appEntry = try #require(viewModel.relatedFiles.first { $0.type == .app })
        // 默认勾选包含 App 本体，卸载按钮才可用（#794）。
        #expect(viewModel.selectedFileIds.contains(appEntry.id))
    }

    // MARK: - 部分删除失败与重试（回归 #410）

    @Test
    func deleteFilesSkipsAlreadyMissingItemsSoRetryIsNotBlocked() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("app-manager-delete-missing-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        // 首项模拟「上一次部分成功已移入废纸篓的 App 本体」：路径已不存在。
        let missingApp = RelatedFile(path: root.appendingPathComponent("Gone.app").path, size: 1, type: .app)
        let tailFile = root.appendingPathComponent("tail.plist")
        try "prefs".write(to: tailFile, atomically: true, encoding: .utf8)
        let tail = RelatedFile(path: tailFile.path, size: 1, type: .preferences)

        let result = await AppService().deleteFiles([missingApp, tail])

        // 已不存在的首项被视为已删除并跳过，不得阻塞其余项；剩余项正常移入废纸篓。
        #expect(result.failed.isEmpty)
        #expect(result.deleted.count == 2)
        #expect(result.deleted.contains { $0.path == missingApp.path })
        #expect(result.deleted.contains { $0.path == tail.path })
        #expect(!FileManager.default.fileExists(atPath: tailFile.path))
    }

    @Test
    func deleteFilesContinuesPastFailureAndReportsPartial() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("app-manager-delete-partial-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let appDir = root.appendingPathComponent("App.app", isDirectory: true)
        try FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        let lockedFile = root.appendingPathComponent("locked.plist")
        try "locked".write(to: lockedFile, atomically: true, encoding: .utf8)
        // 用户不可变标志（uchg）：trashItem 无法移动，确定性失败。
        try FileManager.default.setAttributes([.immutable: true], ofItemAtPath: lockedFile.path)
        defer { try? FileManager.default.setAttributes([.immutable: false], ofItemAtPath: lockedFile.path) }
        let tailFile = root.appendingPathComponent("tail.plist")
        try "tail".write(to: tailFile, atomically: true, encoding: .utf8)

        let appFile = RelatedFile(path: appDir.path, size: 1, type: .app)
        let locked = RelatedFile(path: lockedFile.path, size: 1, type: .preferences)
        let tail = RelatedFile(path: tailFile.path, size: 1, type: .cache)

        let result = await AppService().deleteFiles([appFile, locked, tail])

        // 中间项失败不得中断整批：App 本体与失败项之后的文件仍被删除并计入成功。
        #expect(result.deleted.contains { $0.path == appFile.path })
        #expect(result.deleted.contains { $0.path == tail.path })
        #expect(result.failed.count == 1)
        #expect(result.failed.first?.file.path == locked.path)
        #expect(!FileManager.default.fileExists(atPath: appDir.path))
        #expect(!FileManager.default.fileExists(atPath: tailFile.path))
        #expect(FileManager.default.fileExists(atPath: lockedFile.path))
    }

    @Test
    func partialDeletionRemovesDeletedItemsAndKeepsFailedForRetry() async throws {
        let app = Self.app(path: "/Applications/Partial.app", name: "Partial", size: 1)
        let appFile = RelatedFile(path: app.bundleURL.path, size: 1, type: .app)
        let support = RelatedFile(path: "/Users/x/Library/Application Support/Partial", size: 1, type: .support)
        let cache = RelatedFile(path: "/Users/x/Library/Caches/Partial", size: 1, type: .cache)

        let service = FakeAppManagerService()
        service.deleteHandler = { _ in
            DeleteFilesResult(deleted: [appFile, support], failed: [.init(file: cache, message: "locked")])
        }
        let viewModel = AppManagerViewModel(appService: service)
        viewModel.installedApps = [app]
        viewModel.selectedApp = app
        viewModel.relatedFiles = [appFile, support, cache]
        viewModel.selectedFileIds = [appFile.id, support.id, cache.id]

        viewModel.deleteSelectedFiles()
        try await Self.waitForDeletion(viewModel)

        // 已删除的 App 本体立即从列表移除；成功项从详情与选择中移除。
        #expect(!viewModel.installedApps.contains { $0.bundleURL.path == app.bundleURL.path })
        #expect(viewModel.relatedFiles.map(\.id) == [cache.id])
        #expect(viewModel.selectedFileIds == Set([cache.id]))
        // 保留选择上下文与失败项，供用户修复权限/锁定后重试。
        #expect(viewModel.selectedApp?.bundleURL.path == app.bundleURL.path)
        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.showUninstallConfirmation == false)
    }

    @Test
    func retryAfterPartialFailureClearsRemainingAndCompletes() async throws {
        let app = Self.app(path: "/Applications/Retry.app", name: "Retry", size: 1)
        let appFile = RelatedFile(path: app.bundleURL.path, size: 1, type: .app)
        let cache = RelatedFile(path: "/Users/x/Library/Caches/Retry", size: 1, type: .cache)

        let service = FakeAppManagerService()
        // 第一次：App 本体删除成功、cache 失败；第二次（重试）：剩余项成功。
        service.deleteHandler = { files in
            if files.contains(where: { $0.type == .app }) {
                return DeleteFilesResult(deleted: [appFile], failed: [.init(file: cache, message: "locked")])
            }
            return DeleteFilesResult(deleted: files, failed: [])
        }
        let viewModel = AppManagerViewModel(appService: service)
        viewModel.installedApps = [app]
        viewModel.selectedApp = app
        viewModel.relatedFiles = [appFile, cache]
        viewModel.selectedFileIds = [appFile.id, cache.id]

        viewModel.deleteSelectedFiles()
        try await Self.waitForDeletion(viewModel)
        #expect(viewModel.relatedFiles.map(\.id) == [cache.id])
        #expect(viewModel.selectedFileIds == Set([cache.id]))

        // 重试：只针对剩余的 cache，不再触碰已删除的 App 本体。
        viewModel.deleteSelectedFiles()
        try await Self.waitForDeletion(viewModel)

        let calls = service.deleteCalls.calls
        #expect(calls.count == 2)
        #expect(calls.last?.map(\.id) == [cache.id])
        #expect(viewModel.relatedFiles.isEmpty)
        #expect(viewModel.selectedFileIds.isEmpty)
        #expect(viewModel.selectedApp == nil)
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func successfulExtraOnlyDeletionKeepsAppAndRescans() async throws {
        let app = Self.app(path: "/Applications/Keep.app", name: "Keep", size: 1)
        let appFile = RelatedFile(path: app.bundleURL.path, size: 1, type: .app)
        let support = RelatedFile(path: "/Users/x/Library/Application Support/Keep", size: 1, type: .support)
        let refreshed = [appFile]

        let service = FakeAppManagerService()
        service.relatedFilesByApp[app.bundleURL.path] = refreshed
        service.deleteHandler = { files in DeleteFilesResult(deleted: files, failed: []) }
        let viewModel = AppManagerViewModel(appService: service)
        viewModel.installedApps = [app]
        viewModel.selectedApp = app
        viewModel.relatedFiles = [appFile, support]
        viewModel.selectedFileIds = [support.id]

        viewModel.deleteSelectedFiles()
        try await Self.waitForDeletion(viewModel)
        try await Self.waitForScan(viewModel)

        // App 本体未被删除：仍在列表与选择中，仅关联文件删除后重扫刷新。
        #expect(viewModel.installedApps.contains { $0.bundleURL.path == app.bundleURL.path })
        #expect(viewModel.selectedApp?.bundleURL.path == app.bundleURL.path)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.relatedFiles.map(\.id) == refreshed.map(\.id))
    }

    @Test
    func completeAppDeletionRemovesAppAndClearsSelection() async throws {
        let app = Self.app(path: "/Applications/Full.app", name: "Full", size: 1)
        let appFile = RelatedFile(path: app.bundleURL.path, size: 1, type: .app)
        let support = RelatedFile(path: "/Users/x/Library/Application Support/Full", size: 1, type: .support)

        let service = FakeAppManagerService()
        service.deleteHandler = { files in DeleteFilesResult(deleted: files, failed: []) }
        let viewModel = AppManagerViewModel(appService: service)
        viewModel.installedApps = [app]
        viewModel.selectedApp = app
        viewModel.relatedFiles = [appFile, support]
        viewModel.selectedFileIds = [appFile.id, support.id]

        viewModel.deleteSelectedFiles()
        try await Self.waitForDeletion(viewModel)

        #expect(!viewModel.installedApps.contains { $0.bundleURL.path == app.bundleURL.path })
        #expect(viewModel.selectedApp == nil)
        #expect(viewModel.relatedFiles.isEmpty)
        #expect(viewModel.selectedFileIds.isEmpty)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.showUninstallConfirmation == false)
    }

    @Test
    func staleDeletionResultDoesNotPolluteNewSelection() async throws {
        let appA = Self.app(path: "/Applications/A.app", name: "A", size: 1)
        let appB = Self.app(path: "/Applications/B.app", name: "B", size: 1)
        let aFile = RelatedFile(path: appA.bundleURL.path, size: 1, type: .app)
        let bFile = RelatedFile(path: appB.bundleURL.path, size: 1, type: .app)

        let gate = DeletionGate()
        let service = FakeAppManagerService()
        service.deleteHandler = { _ in
            await gate.wait()
            return DeleteFilesResult(deleted: [aFile], failed: [])
        }
        let viewModel = AppManagerViewModel(appService: service)
        viewModel.installedApps = [appA, appB]
        viewModel.selectedApp = appA
        viewModel.relatedFiles = [aFile]
        viewModel.selectedFileIds = [aFile.id]

        viewModel.deleteSelectedFiles()
        // 删除挂起期间用户切换到 B：旧删除结果晚到，不得污染新上下文。
        viewModel.selectedApp = appB
        viewModel.relatedFiles = [bFile]
        viewModel.selectedFileIds = [bFile.id]

        await gate.release()
        try await Self.waitForDeletion(viewModel)

        #expect(viewModel.selectedApp?.bundleURL.path == appB.bundleURL.path)
        #expect(viewModel.relatedFiles.map(\.id) == [bFile.id])
        #expect(viewModel.selectedFileIds == Set([bFile.id]))
        #expect(viewModel.installedApps.contains { $0.bundleURL.path == appB.bundleURL.path })
        #expect(viewModel.errorMessage == nil)
    }

    private static func waitForDeletion(_ viewModel: AppManagerViewModel) async throws {
        for _ in 0..<400 {
            if !viewModel.isDeleting { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(!viewModel.isDeleting)
    }

    private static func waitForScan(_ viewModel: AppManagerViewModel) async throws {
        for _ in 0..<200 {
            if !viewModel.isScanningFiles { return }
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(!viewModel.isScanningFiles)
    }

    private static func makeAppWithoutBundleID(
        in directory: URL,
        name: String,
        bundleName: String
    ) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let appURL = directory.appendingPathComponent("\(name).app", isDirectory: true)
        let contents = appURL.appendingPathComponent("Contents", isDirectory: true)
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        // 故意不写 CFBundleIdentifier：模拟 Info.plist 缺少 Bundle ID 的应用。
        let plist: [String: Any] = [
            "CFBundleName": bundleName,
            "CFBundlePackageType": "APPL",
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: contents.appendingPathComponent("Info.plist"))
        return appURL
    }

    private static func makeApp(
        in directory: URL,
        name: String,
        bundleName: String,
        bundleIdentifier: String
    ) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let appURL = directory.appendingPathComponent("\(name).app", isDirectory: true)
        let contents = appURL.appendingPathComponent("Contents", isDirectory: true)
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        let plist: [String: Any] = [
            "CFBundleName": bundleName,
            "CFBundleIdentifier": bundleIdentifier,
            "CFBundlePackageType": "APPL",
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: contents.appendingPathComponent("Info.plist"))
        return appURL
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
    /// 按 App 路径配置的关联文件扫描结果（删除成功后刷新用）。
    var relatedFilesByApp: [String: [RelatedFile]] = [:]
    /// 自定义逐项删除结果；为 nil 时默认全部成功。
    var deleteHandler: (([RelatedFile]) async -> DeleteFilesResult)?
    /// 记录每次 deleteFiles 收到的入参，供断言重试只针对剩余项。
    let deleteCalls = RelatedFileCallBox()

    init(results: [Bool: (delay: UInt64, apps: [AppModel])] = [:]) {
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
        relatedFilesByApp[app.bundleURL.path] ?? []
    }

    func deleteFiles(_ files: [RelatedFile]) async -> DeleteFilesResult {
        deleteCalls.record(files)
        if let deleteHandler {
            return await deleteHandler(files)
        }
        return DeleteFilesResult(deleted: files, failed: [])
    }

    func saveCache() async {}

    func revealInFinder(_ app: AppModel) {}

    func openApp(_ app: AppModel) {}

    func getAppInfo(_ app: AppModel) -> String {
        app.displayName
    }
}

/// 线程安全的 deleteFiles 入参记录器（写入发生在非主线程的删除 Task 中）。
private final class RelatedFileCallBox: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [[RelatedFile]] = []

    func record(_ files: [RelatedFile]) {
        lock.lock()
        storage.append(files)
        lock.unlock()
    }

    var calls: [[RelatedFile]] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}

/// 异步门闩：`wait()` 挂起直到 `release()`，用于确定性地构造「删除尚未完成、
/// 用户已切换选择」的旧请求晚到中间态（Swift 6 下不在 async 闭包里用信号量阻塞）。
private actor DeletionGate {
    private var continuations: [CheckedContinuation<Void, Never>] = []
    private var released = false

    func wait() async {
        if released { return }
        await withCheckedContinuation { continuation in
            continuations.append(continuation)
        }
    }

    func release() {
        released = true
        let pending = continuations
        continuations.removeAll()
        for continuation in pending {
            continuation.resume()
        }
    }
}
