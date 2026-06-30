import Foundation
import LumiCoreKit
import Testing

@testable import LumiCoreKit

@Suite(.serialized)
struct ProviderRenderKindManagerTests {

    // MARK: - Setup & Teardown

    /// 使用独立的管理器实例以避免全局单例 `shared` 导致的测试间污染。
    /// 由于 `ProviderRenderKindManager.init` 是 `private`，
    /// 我们在每个测试开始前通过 `shared.reset()` 重置状态。
    private func freshManager() -> ProviderRenderKindManager {
        let manager = ProviderRenderKindManager.shared
        manager.reset()
        return manager
    }

    // MARK: - Register

    @Test
    func registerProviderPrefix_storesMapping() {
        let manager = freshManager()

        manager.registerProviderPrefix("zhipu-", for: "zhipu")

        #expect(manager.providerPrefix(for: "zhipu") == "zhipu-")
        #expect(manager.allProviderIds() == ["zhipu"])
        #expect(manager.allProviderPrefixes() == ["zhipu-"])
    }

    @Test
    func registerProviderPrefix_overwritesExistingProvider() {
        let manager = freshManager()

        manager.registerProviderPrefix("zhipu-", for: "zhipu")
        manager.registerProviderPrefix("zhipu-v2-", for: "zhipu")

        #expect(manager.providerPrefix(for: "zhipu") == "zhipu-v2-")
        #expect(manager.allProviderIds() == ["zhipu"])
        #expect(manager.allProviderPrefixes() == ["zhipu-v2-"])
    }

    @Test
    func registerProviderPrefix_multipleProviders() {
        let manager = freshManager()

        manager.registerProviderPrefix("zhipu-", for: "zhipu")
        manager.registerProviderPrefix("aliyun-", for: "aliyun")
        manager.registerProviderPrefix("stepfun-", for: "stepfun")

        #expect(manager.allProviderIds() == ["zhipu", "aliyun", "stepfun"])
        #expect(manager.allProviderPrefixes() == ["zhipu-", "aliyun-", "stepfun-"])
    }

    // MARK: - Unregister

    @Test
    func unregisterProviderPrefix_removesMapping() {
        let manager = freshManager()

        manager.registerProviderPrefix("zhipu-", for: "zhipu")
        manager.unregisterProviderPrefix(for: "zhipu")

        #expect(manager.providerPrefix(for: "zhipu") == nil)
        #expect(manager.allProviderIds().isEmpty)
        #expect(manager.allProviderPrefixes().isEmpty)
    }

    @Test
    func unregisterProviderPrefix_nonExistentProvider_doesNotCrash() {
        let manager = freshManager()

        manager.registerProviderPrefix("zhipu-", for: "zhipu")
        manager.unregisterProviderPrefix(for: "non-existent")

        #expect(manager.allProviderIds() == ["zhipu"])
    }

    @Test
    func unregisterProviderPrefix_onlyRemovesTargetProvider() {
        let manager = freshManager()

        manager.registerProviderPrefix("zhipu-", for: "zhipu")
        manager.registerProviderPrefix("aliyun-", for: "aliyun")
        manager.unregisterProviderPrefix(for: "zhipu")

        #expect(manager.allProviderIds() == ["aliyun"])
        #expect(manager.allProviderPrefixes() == ["aliyun-"])
    }

    // MARK: - isProviderSpecificRenderKind

    @Test
    func isProviderSpecificRenderKind_returnsTrueForRegisteredPrefix() {
        let manager = freshManager()
        manager.registerProviderPrefix("zhipu-", for: "zhipu")

        #expect(manager.isProviderSpecificRenderKind("zhipu-http-401") == true)
        #expect(manager.isProviderSpecificRenderKind("zhipu-api-key-missing") == true)
        #expect(manager.isProviderSpecificRenderKind("zhipu-request-failed") == true)
    }

    @Test
    func isProviderSpecificRenderKind_returnsFalseForUnregisteredPrefix() {
        let manager = freshManager()
        manager.registerProviderPrefix("zhipu-", for: "zhipu")

        #expect(manager.isProviderSpecificRenderKind("unknown-error") == false)
        #expect(manager.isProviderSpecificRenderKind("core-error") == false)
    }

    @Test
    func isProviderSpecificRenderKind_returnsFalseForNil() {
        let manager = freshManager()
        manager.registerProviderPrefix("zhipu-", for: "zhipu")

        #expect(manager.isProviderSpecificRenderKind(nil) == false)
    }

    @Test
    func isProviderSpecificRenderKind_returnsFalseWhenNoProviders() {
        let manager = freshManager()

        #expect(manager.isProviderSpecificRenderKind("zhipu-http-401") == false)
    }

    @Test
    func isProviderSpecificRenderKind_matchesMultipleProviders() {
        let manager = freshManager()
        manager.registerProviderPrefix("zhipu-", for: "zhipu")
        manager.registerProviderPrefix("aliyun-", for: "aliyun")
        manager.registerProviderPrefix("stepfun-", for: "stepfun")

        #expect(manager.isProviderSpecificRenderKind("zhipu-http-401") == true)
        #expect(manager.isProviderSpecificRenderKind("aliyun-api-key-missing") == true)
        #expect(manager.isProviderSpecificRenderKind("stepfun-request-failed") == true)
        #expect(manager.isProviderSpecificRenderKind("unknown-error") == false)
    }

    // MARK: - isRenderKind(_:ownedBy:)

    @Test
    func isRenderKind_ownedBy_returnsTrueForMatchingProvider() {
        let manager = freshManager()
        manager.registerProviderPrefix("zhipu-", for: "zhipu")

        #expect(manager.isRenderKind("zhipu-http-401", ownedBy: "zhipu") == true)
    }

    @Test
    func isRenderKind_ownedBy_returnsFalseForDifferentProvider() {
        let manager = freshManager()
        manager.registerProviderPrefix("zhipu-", for: "zhipu")
        manager.registerProviderPrefix("aliyun-", for: "aliyun")

        #expect(manager.isRenderKind("zhipu-http-401", ownedBy: "aliyun") == false)
    }

    @Test
    func isRenderKind_ownedBy_returnsFalseForUnregisteredProvider() {
        let manager = freshManager()

        #expect(manager.isRenderKind("zhipu-http-401", ownedBy: "zhipu") == false)
    }

    @Test
    func isRenderKind_ownedBy_returnsFalseForNil() {
        let manager = freshManager()
        manager.registerProviderPrefix("zhipu-", for: "zhipu")

        #expect(manager.isRenderKind(nil, ownedBy: "zhipu") == false)
    }

    // MARK: - providerPrefix(for:)

    @Test
    func providerPrefix_returnsPrefixForRegisteredProvider() {
        let manager = freshManager()
        manager.registerProviderPrefix("stepfun-", for: "stepfun")

        #expect(manager.providerPrefix(for: "stepfun") == "stepfun-")
    }

    @Test
    func providerPrefix_returnsNilForUnregisteredProvider() {
        let manager = freshManager()

        #expect(manager.providerPrefix(for: "unknown") == nil)
    }

    // MARK: - allProviderPrefixes / allProviderIds

    @Test
    func allProviderPrefixes_returnsEmptyWhenNoProviders() {
        let manager = freshManager()

        #expect(manager.allProviderPrefixes().isEmpty)
    }

    @Test
    func allProviderIds_returnsEmptyWhenNoProviders() {
        let manager = freshManager()

        #expect(manager.allProviderIds().isEmpty)
    }

    // MARK: - reset

    @Test
    func reset_clearsAllRegistrations() {
        let manager = freshManager()

        manager.registerProviderPrefix("zhipu-", for: "zhipu")
        manager.registerProviderPrefix("aliyun-", for: "aliyun")

        manager.reset()

        #expect(manager.allProviderIds().isEmpty)
        #expect(manager.allProviderPrefixes().isEmpty)
        #expect(manager.isProviderSpecificRenderKind("zhipu-http-401") == false)
        #expect(manager.providerPrefix(for: "zhipu") == nil)
    }

    // MARK: - Real-world scenario

    @Test
    func realWorldScenario_simulatesAllRegisteredProviders() {
        let manager = freshManager()

        // 模拟所有 LLM 提供商插件注册
        manager.registerProviderPrefix("zhipu-", for: "zhipu")
        manager.registerProviderPrefix("aliyun-", for: "aliyun")
        manager.registerProviderPrefix("xiaomi-", for: "xiaomi")
        manager.registerProviderPrefix("mlx-", for: "mlx")
        manager.registerProviderPrefix("sublyx-", for: "sublyx")
        manager.registerProviderPrefix("stepfun-", for: "stepfun")

        #expect(manager.allProviderIds().count == 6)
        #expect(manager.allProviderPrefixes().count == 6)

        // 验证每个提供商的错误消息都被正确识别
        #expect(manager.isProviderSpecificRenderKind("zhipu-http-401") == true)
        #expect(manager.isProviderSpecificRenderKind("aliyun-api-key-missing") == true)
        #expect(manager.isProviderSpecificRenderKind("xiaomi-request-failed") == true)
        #expect(manager.isProviderSpecificRenderKind("mlx-model-not-downloaded") == true)
        #expect(manager.isProviderSpecificRenderKind("sublyx-http-500") == true)
        #expect(manager.isProviderSpecificRenderKind("stepfun-http-403") == true)

        // 通用错误消息不应被识别为提供商特定
        #expect(manager.isProviderSpecificRenderKind("core-error") == false)
        #expect(manager.isProviderSpecificRenderKind("turn-completed") == false)
        #expect(manager.isProviderSpecificRenderKind(nil) == false)
    }
}
