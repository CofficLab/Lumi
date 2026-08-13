import Foundation
import KeychainKit
import LLMKit
import KernelLumi
import Testing
@testable import LLMProviderDeepSeekPlugin

// MARK: - 内存 Keychain backend（不污染真实 Keychain）
//
// `APIKeyStore` 内部持有 `KeychainStore`，而 `KeychainStore` 接受一个
// `KeychainBackend` 协议。测试里注入内存版 backend，所有读写都走字典，
// 跑完即清空，不会影响用户机器上真实的 `com.coffic.lumi.apikey` 条目。

private final class InMemoryKeychainBackend: KeychainBackend, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: Data] = [:]
    // key = "service::account"，value = raw bytes
    private func key(_ service: String, _ account: String) -> String {
        "\(service)::\(account)"
    }

    func read(service: String, account: String) -> KeychainResult {
        lock.lock()
        defer { lock.unlock() }
        if let data = storage[key(service, account)] {
            return KeychainResult(status: errSecSuccess, data: data)
        }
        return KeychainResult(status: errSecItemNotFound, data: nil)
    }

    func write(_ data: Data, service: String, account: String) -> KeychainResult {
        lock.lock()
        defer { lock.unlock() }
        storage[key(service, account)] = data
        return KeychainResult(status: errSecSuccess, data: data)
    }

    func delete(service: String, account: String) -> KeychainResult {
        lock.lock()
        defer { lock.unlock() }
        storage.removeValue(forKey: key(service, account))
        return KeychainResult(status: errSecSuccess, data: nil)
    }
}

// MARK: - 测试辅助

/// 隔离的 `APIKeyStore`，与 `APIKeyStore.shared` 完全独立。
private func makeIsolatedAPIKeyStore() -> APIKeyStore {
    let backend = InMemoryKeychainBackend()
    let store = KeychainStore(service: "com.coffic.lumi.apikey.test", backend: backend)
    return APIKeyStore(store: store)
}

/// 在测试期间把 `DeepSeekPlugin` 的入口切到隔离 store，结束后还原。
/// 整个生命周期（设置 + 闭包 + 还原）走 `_DeepSeekPluginKeyStoreBridge`
/// 的同一把锁，避免 Swift Testing 并发跑测试时互相覆盖。
private func withIsolatedKeyStore<R>(_ body: () throws -> R) rethrows -> R {
    let isolated = makeIsolatedAPIKeyStore()
    return try _DeepSeekPluginKeyStoreBridge.shared.withOverride(isolated, body)
}

// MARK: - 核心契约：三个入口必须读到同一个 key
//
// 这正是本次重构要锁住的属性：
// 1. Http401Renderer 通过 `DeepSeekPlugin.currentApiKey` 读
// 2. DeepSeekOpenAIProvider 通过 `lumiResolveAPIKey()` / `getApiKey()` 读
// 3. DeepSeekAnthropicProvider 通过 `lumiResolveAPIKey()` / `getApiKey()` 读
//
// 重构前曾经因为 (service, account) 漂移导致这三者读到不同值。

@Suite("API Key 统一入口")
struct DeepSeekPluginAPIKeyUnificationTests {

    @Test("DeepSeekPlugin.currentApiKey 与两个 Provider 的 getApiKey() 返回一致")
    func currentApiKeyMatchesProviders() {
        withIsolatedKeyStore {
            let key = "sk-test-\(UUID().uuidString)"
            DeepSeekPlugin.setApiKey(key)

            #expect(DeepSeekPlugin.currentApiKey == key)
            #expect(DeepSeekPlugin.hasApiKey)
            #expect(DeepSeekOpenAIProvider().getApiKey() == key)
            #expect(DeepSeekAnthropicProvider().getApiKey() == key)
        }
    }

    @Test("未配置时 currentApiKey 为空串，hasApiKey 为 false")
    func emptyWhenUnset() {
        withIsolatedKeyStore {
            // 测试环境里如果 setOverride 时隔离 store 已经有值（不太可能），
            // 显式清理一次，确保起点干净。
            DeepSeekPlugin.removeApiKey()

            #expect(DeepSeekPlugin.currentApiKey.isEmpty)
            #expect(!DeepSeekPlugin.hasApiKey)
            #expect(DeepSeekOpenAIProvider().getApiKey().isEmpty)
            #expect(DeepSeekAnthropicProvider().getApiKey().isEmpty)
        }
    }

    @Test("lumiResolveAPIKey() 在未配置时抛错")
    func resolveThrowsWhenUnset() {
        withIsolatedKeyStore {
            // 显式清空隔离 store（不依赖 removeApiKey 的 UserDefaults 迁移路径）。
            DeepSeekPlugin.removeApiKey()

            // sanity check：清空后 currentApiKey 必须为空。
            #expect(DeepSeekPlugin.currentApiKey.isEmpty)

            do {
                _ = try DeepSeekOpenAIProvider().lumiResolveAPIKey()
                Issue.record("DeepSeekOpenAIProvider.lumiResolveAPIKey 未抛错")
            } catch {
                // 任意 Error 即可（missingAPIKey / apiKeyAccessFailed 都接受）
            }
            do {
                _ = try DeepSeekAnthropicProvider().lumiResolveAPIKey()
                Issue.record("DeepSeekAnthropicProvider.lumiResolveAPIKey 未抛错")
            } catch {
                // 任意 Error 即可
            }
        }
    }

    @Test("两个 Provider 的 apiKeyStorageKey 引用同一常量")
    func storageKeyIsUnified() {
        // 关键不变性：两个 Provider 的 storage key 必须指向同一个常量，
        // 否则历史上那种"displayName 一样但 key 不一样"导致的 bug 会复发。
        #expect(DeepSeekOpenAIProvider.info._apiKeyStorageKey == DeepSeekPlugin.apiKeyStorageKey)
        #expect(DeepSeekAnthropicProvider.info._apiKeyStorageKey == DeepSeekPlugin.apiKeyStorageKey)
        #expect(DeepSeekOpenAIProvider.info._apiKeyStorageKey == DeepSeekAnthropicProvider.info._apiKeyStorageKey)
    }

    @Test("setApiKey 写一次，三个入口都能读出")
    func singleWriteVisibleToAll() {
        withIsolatedKeyStore {
            DeepSeekPlugin.setApiKey("sk-shared-1")
            #expect(DeepSeekPlugin.currentApiKey == "sk-shared-1")
            #expect(DeepSeekOpenAIProvider().getApiKey() == "sk-shared-1")
            #expect(DeepSeekAnthropicProvider().getApiKey() == "sk-shared-1")
            // 反向写一次也对称
            DeepSeekOpenAIProvider().setApiKey("sk-shared-2")
            #expect(DeepSeekPlugin.currentApiKey == "sk-shared-2")
            #expect(DeepSeekAnthropicProvider().getApiKey() == "sk-shared-2")
        }
    }

    @Test("removeApiKey 后所有入口都为空")
    func removeClearsAll() {
        withIsolatedKeyStore {
            DeepSeekPlugin.setApiKey("sk-temp")
            #expect(DeepSeekPlugin.hasApiKey)

            DeepSeekPlugin.removeApiKey()

            #expect(!DeepSeekPlugin.hasApiKey)
            #expect(DeepSeekPlugin.currentApiKey.isEmpty)
            #expect(DeepSeekOpenAIProvider().getApiKey().isEmpty)
            #expect(DeepSeekAnthropicProvider().getApiKey().isEmpty)
        }
    }

    @Test("空串写入等价于删除")
    func emptyStringWriteDeletes() {
        withIsolatedKeyStore {
            DeepSeekPlugin.setApiKey("sk-non-empty")
            #expect(DeepSeekPlugin.hasApiKey)

            DeepSeekPlugin.setApiKey("   ")

            // KeychainStore.set 内部会 trim；纯空白被认为空，等价于删除。
            #expect(!DeepSeekPlugin.hasApiKey)
        }
    }
}
