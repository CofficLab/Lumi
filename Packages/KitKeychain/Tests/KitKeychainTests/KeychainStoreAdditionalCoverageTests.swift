import Foundation
import Security
import Testing
@testable import KitKeychain

// MARK: - 可脚本化的内存后端

private final class ScriptedBackend: KeychainBackend, @unchecked Sendable {
    /// 每次 read 依次返回的结果；耗尽后重复最后一个。
    var readResults: [KeychainResult]
    /// 记录每次 read 调用时传入的 allowInteraction。
    private(set) var readAllowInteractions: [Bool] = []
    private(set) var readCalls = 0

    var writeResult: KeychainResult
    private(set) var writes: [(Data, String, String)] = []

    var deleteResult: KeychainResult
    private(set) var deletes: [(String, String)] = []

    init(readResults: [KeychainResult],
         writeResult: KeychainResult = KeychainResult(status: errSecSuccess, data: nil),
         deleteResult: KeychainResult = KeychainResult(status: errSecSuccess, data: nil)) {
        self.readResults = readResults
        self.writeResult = writeResult
        self.deleteResult = deleteResult
    }

    func read(service: String, account: String, allowInteraction: Bool) -> KeychainResult {
        readAllowInteractions.append(allowInteraction)
        defer { readCalls += 1 }
        guard readResults.isEmpty == false else {
            return KeychainResult(status: errSecItemNotFound, data: nil)
        }
        let idx = min(readCalls, readResults.count - 1)
        return readResults[idx]
    }

    func write(_ data: Data, service: String, account: String) -> KeychainResult {
        writes.append((data, service, account))
        return writeResult
    }

    func delete(service: String, account: String) -> KeychainResult {
        deletes.append((service, account))
        return deleteResult
    }
}

private func valueResult(_ s: String) -> KeychainResult {
    KeychainResult(status: errSecSuccess, data: Data(s.utf8))
}

private let missingResult = KeychainResult(status: errSecItemNotFound, data: nil)

@Suite("KeychainStore 补充覆盖二")
struct KeychainStoreRetryMigrationTests {

    private func makeStore(backend: ScriptedBackend) -> KeychainStore {
        // 注入空 sleeper，避免真实等待。
        KeychainStore(service: "com.lumi.tests", backend: backend, sleeper: { _ in })
    }

    // MARK: - 瞬时失败后重试成功

    @Test("瞬时失败后重试成功，且只在第一次前退避一次")
    func transientThenSuccessRecovers() throws {
        let backend = ScriptedBackend(readResults: [
            KeychainResult(status: errSecNotAvailable, data: nil),  // 第 1 次：瞬时失败
            valueResult("secret-value"),                            // 第 2 次：成功
        ])
        let store = makeStore(backend: backend)

        let result = try store.stringReportingErrors(forKey: "token")

        #expect(result == "secret-value")
        #expect(backend.readCalls == 2)
    }

    @Test("瞬时失败后 read 允许交互（默认路径）")
    func defaultReadAllowsInteraction() throws {
        let backend = ScriptedBackend(readResults: [valueResult("v")])
        let store = makeStore(backend: backend)
        _ = try store.stringReportingErrors(forKey: "k")
        #expect(backend.readAllowInteractions == [true])
    }

    // MARK: - stringWithoutPrompt 成功路径

    @Test("stringWithoutPrompt 成功返回值且以 allowInteraction=false 读取")
    func stringWithoutPromptSuccess() throws {
        let backend = ScriptedBackend(readResults: [valueResult("headless-token")])
        let store = makeStore(backend: backend)

        let result = store.stringWithoutPrompt(forKey: "headless")

        #expect(result == "headless-token")
        #expect(backend.readAllowInteractions == [false])
    }

    // MARK: - 无提示迁移路径

    @Test("无提示迁移：keychain 为空时从 UserDefaults 迁移并写回 keychain")
    func noPromptMigrationMigratesLegacyValue() throws {
        let key = "lumi-migrate-\(UUID().uuidString)"
        UserDefaults.standard.set("legacy-token", forKey: key)
        defer { UserDefaults.standard.removeObject(forKey: key) }

        let backend = ScriptedBackend(readResults: [missingResult])
        let store = makeStore(backend: backend)

        let result = try store.loadMigratingLegacyUserDefaultsWithoutPromptReportingErrors(forKey: key)

        #expect(result == "legacy-token")
        // 读取走无提示路径
        #expect(backend.readAllowInteractions == [false])
        // 写回 keychain 成功
        #expect(backend.writes.count == 1)
        #expect(String(data: backend.writes[0].0, encoding: .utf8) == "legacy-token")
        // legacy 值已被清理
        #expect(UserDefaults.standard.string(forKey: key) == nil)
    }

    @Test("迁移时 keychain 写入失败则抛错且保留 legacy 值不丢失")
    func migrationPropagatesWriteFailure() throws {
        let key = "lumi-migrate-fail-\(UUID().uuidString)"
        UserDefaults.standard.set("do-not-lose-me", forKey: key)
        defer { UserDefaults.standard.removeObject(forKey: key) }

        let backend = ScriptedBackend(
            readResults: [missingResult],
            writeResult: KeychainResult(status: errSecAuthFailed, data: nil)
        )
        let store = makeStore(backend: backend)

        do {
            _ = try store.loadMigratingLegacyUserDefaultsReportingErrors(forKey: key)
            Issue.record("期望 writeFailed")
        } catch let error as KeychainStoreError {
            guard case .writeFailed(let status) = error else {
                Issue.record("期望 writeFailed，实际 \(error)")
                return
            }
            #expect(status == errSecAuthFailed)
        } catch {
            Issue.record("意外错误: \(error)")
        }

        // 写失败 → legacy 值必须原样保留
        #expect(UserDefaults.standard.string(forKey: key) == "do-not-lose-me")
    }

    @Test("keychain 已有值时不触发 UserDefaults 迁移")
    func prefersKeychainOverLegacy() throws {
        let key = "lumi-prefer-\(UUID().uuidString)"
        UserDefaults.standard.set("legacy", forKey: key)
        defer { UserDefaults.standard.removeObject(forKey: key) }

        let backend = ScriptedBackend(readResults: [valueResult("keychain-value")])
        let store = makeStore(backend: backend)

        let result = try store.loadMigratingLegacyUserDefaultsReportingErrors(forKey: key)

        #expect(result == "keychain-value")
        // 不应写回（keychain 已有）
        #expect(backend.writes.isEmpty)
        // legacy 值保留（未迁移）
        #expect(UserDefaults.standard.string(forKey: key) == "legacy")
    }

    // MARK: - KeychainBackend 扩展默认参数

    @Test("KeychainBackend 扩展 read(service:account:) 默认 allowInteraction=true")
    func backendExtensionDefaultsToInteractive() {
        let backend = ScriptedBackend(readResults: [valueResult("x")])
        // 调用协议扩展的两参 read
        let result = backend.read(service: "s", account: "a")
        #expect(result.status == errSecSuccess)
        #expect(backend.readAllowInteractions == [true])
    }
}
