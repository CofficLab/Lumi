import Foundation
import KitTestIsolation
import Testing
@testable import NettoPlugin

// MARK: - 进程级隔离注入

/// `AppSettingRepo.shared` 的进程级隔离注入。
///
/// - Important: `shared` 是 `static let`，**首次访问时**就把目录固定下来，
///   之后再改注入值也不再影响它。因此注入必须发生在首次访问之前，
///   而且整个进程只注入一次、**永不撤销**：
///   若某个用例把注入清成 `nil`，另一个用例随后首次访问 `shared`
///   就会撞上目录守卫，整个测试进程被杀掉（signal 5）。
/// - Note: 注入目录整个测试进程共用一个，进程退出后由系统回收；
///   这样即便用例并发执行，单例拿到的目录也始终一致。
enum NettoSharedRepoIsolation {

    /// 进程级注入目录。
    static let directory: URL = {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("PluginNettoTests-shared-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    private static let lock = NSLock()
    private static nonisolated(unsafe) var installed = false

    /// 在任何触碰 `AppSettingRepo.shared` 之前调用（幂等）。
    static func install() {
        lock.lock()
        defer { lock.unlock() }
        guard !installed else { return }
        installed = true
        AppSettingRepo.injectedDefaultDirectory = directory
    }
}

// MARK: - 目录守卫

/// `AppSettingRepo` 默认目录的守卫用例。
@Suite("Netto 默认目录守卫", .serialized)
struct NettoDirectoryGuardTests {

    /// 注入临时目录后，单例的设置文件必须落在该目录里。
    ///
    /// 单例一旦创建就固定了目录，所以这条用例同时锁住「注入必须发生在
    /// 首次访问之前」这条契约。
    @Test("注入目录后 shared 的设置文件落在该目录")
    func usesInjectedDirectory() {
        NettoSharedRepoIsolation.install()

        let repo = AppSettingRepo.shared
        repo.save()

        let expected = NettoSharedRepoIsolation.directory.appendingPathComponent("settings.json")
        #expect(FileManager.default.fileExists(atPath: expected.path))
    }

    /// 未注入目录时守卫必须拒绝回退到本机真实数据目录。
    @Test("未注入目录时守卫拒绝回退到真实数据目录")
    func refusesFallbackWithoutInjection() {
        NettoSharedRepoIsolation.install()
        // 先把单例固定下来：此后改注入值不再影响它，清空注入也不会让
        // 其它用例撞上守卫。
        _ = AppSettingRepo.shared

        AppSettingRepo.injectedDefaultDirectory = nil
        defer { AppSettingRepo.injectedDefaultDirectory = NettoSharedRepoIsolation.directory }
        let injected = AppSettingRepo.injectedDefaultDirectory
        #expect(injected == nil)

        switch IsolatedDirectoryGuard.resolve(
            injected: injected,
            owner: "AppSettingRepo",
            accessor: "defaultSettingsFileURL()",
            fallback: { URL(fileURLWithPath: "/tmp/netto-fallback", isDirectory: true) }
        ) {
        case .resolved:
            Issue.record("测试进程下未注入目录时不应回退到真实数据目录")
        case let .refused(reason):
            #expect(reason.contains("AppSettingRepo"))
            #expect(reason.contains("defaultSettingsFileURL()"))
        }
    }
}
