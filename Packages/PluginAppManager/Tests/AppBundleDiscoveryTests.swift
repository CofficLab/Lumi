import Foundation
import Testing
@testable import AppManagerPlugin

/// Regression coverage for #648: the installed-app scan only accepted direct
/// children of each root whose extension was `app`, so everything macOS keeps in
/// `/System/Applications/Utilities` (Terminal, Activity Monitor, Console) and in
/// `/Applications/Utilities` was invisible and unmanageable.
///
/// The fix enumerates direct children plus one level inside standard application
/// container directories (`Utilities`), without entering `.app` bundles or
/// recursing arbitrary trees. Roots and the cache database are injectable so the
/// real `scanInstalledApps` path can be exercised on a temporary fixture.
struct AppBundleDiscoveryTests {

    @Test
    func scanFindsAppsInsideUtilitiesContainer() async throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        try fixture.makeBundle("Top.app")
        try fixture.makeBundle("Utilities/Terminal.app")
        try fixture.makeBundle("Utilities/Activity Monitor.app")

        let service = AppService(
            homeDirectory: fixture.root.path,
            applicationRoots: [fixture.root.path],
            cacheManager: CacheManager(pluginDataDirectory: fixture.cacheDirectory)
        )
        let apps = await service.scanInstalledApps(force: true)

        // 容器里的系统工具必须与直接子项一起出现，否则无法被管理/卸载。
        #expect(Set(apps.map(\.displayName)) == ["Top", "Terminal", "Activity Monitor"])
        // 枚举返回真实路径（/private/var/...），临时目录 URL 是 /var/...：两侧同样规范化后比较。
        let terminalPath = fixture.root.appendingPathComponent("Utilities/Terminal.app")
            .resolvingSymlinksInPath().path
        #expect(apps.contains { $0.bundleURL.resolvingSymlinksInPath().path == terminalPath })
    }

    @Test
    func discoveryStopsAtOneLevelAndNeverEntersAppBundles() throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        try fixture.makeBundle("Top.app")
        try fixture.makeBundle("Utilities/Terminal.app")
        try fixture.makeBundle("Utilities/Nested/Deep.app")
        try fixture.makeBundle("Other/Stray.app")
        try fixture.makeBundle("Top.app/Contents/Inner.app")

        let found = AppService.appBundleURLs(under: fixture.root)

        // 只下降标准容器的一层：更深的目录、非容器目录与 .app 包内部都不得遍历。
        #expect(Set(found.map(\.lastPathComponent)) == ["Top.app", "Terminal.app"])
    }

    @Test
    func discoveryStillReturnsDirectAppChildren() throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        try fixture.makeBundle("Direct.app")
        try fixture.makeDirectory("Utilities")

        let found = AppService.appBundleURLs(under: fixture.root)

        // 空的容器目录不得影响既有行为：直接子项照常返回。
        #expect(found.map(\.lastPathComponent) == ["Direct.app"])
    }

    @Test
    func discoverySkipsHiddenEntries() throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        try fixture.makeBundle("Visible.app")
        try fixture.makeBundle(".Hidden.app")
        try fixture.makeBundle("Utilities/Console.app")
        try fixture.makeBundle("Utilities/.Secret.app")

        let found = AppService.appBundleURLs(under: fixture.root)

        #expect(Set(found.map(\.lastPathComponent)) == ["Visible.app", "Console.app"])
    }

    // MARK: - Helpers

    /// 临时扫描根 + 独立缓存数据库目录，避免测试触碰真实应用目录与共享缓存。
    private struct Fixture {
        let root: URL
        let cacheDirectory: URL
        private let base: URL

        init() throws {
            base = FileManager.default.temporaryDirectory
                .appendingPathComponent("app-manager-648-\(UUID().uuidString)", isDirectory: true)
            root = base.appendingPathComponent("Applications", isDirectory: true)
            cacheDirectory = base.appendingPathComponent("Cache", isDirectory: true)
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        }

        func makeDirectory(_ relativePath: String) throws {
            try FileManager.default.createDirectory(
                at: root.appendingPathComponent(relativePath, isDirectory: true),
                withIntermediateDirectories: true
            )
        }

        func makeBundle(_ relativePath: String) throws {
            try makeDirectory(relativePath)
        }

        func cleanUp() {
            try? FileManager.default.removeItem(at: base)
        }
    }
}