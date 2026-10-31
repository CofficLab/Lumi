import Foundation
import Security
import KitKeychain
import KitMail
@testable import PluginMail

/// 测试夹具自身的错误。
enum FixtureError: Error {
    case cannotCreateDefaultsSuite
}

/// 测试专用的内存 Keychain backend：不触碰系统 Keychain。
///
/// 让涉及账户凭据的测试与本机既有数据**完全无关**——既不会读到用户真实密码，
/// 也不会在清理时删掉它们。行为契约与 `SystemKeychainBackend` 一致：
/// 未命中返回 `errSecItemNotFound`。
final class InMemoryKeychainBackend: KeychainBackend, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: Data] = [:]

    func read(service: String, account: String, allowInteraction: Bool) -> KeychainResult {
        lock.withLock {
            guard let data = storage[key(service: service, account: account)] else {
                return KeychainResult(status: errSecItemNotFound, data: nil)
            }
            return KeychainResult(status: errSecSuccess, data: data)
        }
    }

    func write(_ data: Data, service: String, account: String) -> KeychainResult {
        lock.withLock {
            storage[key(service: service, account: account)] = data
            return KeychainResult(status: errSecSuccess, data: nil)
        }
    }

    func delete(service: String, account: String) -> KeychainResult {
        lock.withLock {
            storage.removeValue(forKey: key(service: service, account: account))
            return KeychainResult(status: errSecSuccess, data: nil)
        }
    }

    private func key(service: String, account: String) -> String { "\(service)|\(account)" }
}

/// 账户存储测试夹具：临时目录 + 内存 Keychain，生命周期由 XCTest 管理。
///
/// - Important: 之所以做成夹具而不是每个测试类各写一遍，是因为
///   `MailAccountStore` 的实例**必须**由测试持有并注入到被测对象；
///   一旦有人图省事写回静态方法，就会退回到读写真实 Keychain 的老问题。
///   这里没有 `reset()` 全局方法可调用，正是刻意的。
final class MailAccountStoreFixture {
    let store: MailAccountStore
    /// 暴露给需要直接断言落盘路径的用例（验证存储遵循插件目录规范）。
    let directoryForAssertions: URL
    /// 模拟旧版 `UserDefaults` 数据源；每个夹具独占一个 suite。
    let legacyDefaults: UserDefaults
    private let directory: URL
    private let suiteName: String

    init(legacyAccounts: [MailAccountConfig]? = nil) throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PluginMailTests-\(UUID().uuidString)", isDirectory: true)
        directoryForAssertions = directory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        suiteName = "com.coffic.lumi.mail.tests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw FixtureError.cannotCreateDefaultsSuite
        }
        legacyDefaults = defaults
        if let legacyAccounts {
            defaults.set(try JSONEncoder().encode(legacyAccounts), forKey: "MailPlugin.savedAccounts")
        }

        store = MailAccountStore(
            directory: directory,
            keychain: Self.makeKeychain(),
            legacyDefaults: defaults
        )
    }

    deinit {
        legacyDefaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: directory)
    }

    /// 在**同一目录**上新建一个 store，配一个全新的内存 Keychain。
    ///
    /// 用于模拟「App 重启」：配置必须能从磁盘读回，而密码因为 Keychain 是空的
    /// 读不到——这正好把「配置归磁盘、密码归 Keychain」这两条边界分别锁住。
    /// - Parameter legacyDefaults: 迁移数据源；传 `nil` 表示这次启动不再迁移。
    func reopenedStore(legacyDefaults: UserDefaults? = nil) -> MailAccountStore {
        MailAccountStore(
            directory: directory,
            keychain: Self.makeKeychain(),
            legacyDefaults: legacyDefaults
        )
    }

    private static func makeKeychain() -> KeychainStore {
        KeychainStore(
            service: "com.coffic.lumi.mail.tests",
            backend: InMemoryKeychainBackend(),
            sleeper: { _ in }
        )
    }
}

/// 插件本地偏好存储夹具：临时目录。
final class MailLocalStoreFixture {
    let store: MailPluginLocalStore
    private let directory: URL

    init() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PluginMailLocalStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        store = MailPluginLocalStore(directory: directory)
    }

    var directoryForAssertions: URL { directory }

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }
}
