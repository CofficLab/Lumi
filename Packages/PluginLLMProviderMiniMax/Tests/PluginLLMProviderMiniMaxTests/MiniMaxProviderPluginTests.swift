import Foundation
import KernelCore
import KitLLM
import ProviderLLMManager
import Testing
@testable import PluginLLMProviderMiniMax

@MainActor
struct MiniMaxProviderPluginTests {

    @Test("插件身份与元数据稳定")
    func pluginIdentityAndMetadata() {
        let plugin = MiniMaxProviderPlugin()

        #expect(plugin.id == "com.coffic.lumi.plugin.llm-provider.minimax")
        #expect(plugin.order == 100)

        #expect(plugin.metadata.id == "com.coffic.lumi.plugin.llm-provider.minimax")
        #expect(plugin.metadata.name == "MiniMax 供应商")
        #expect(plugin.metadata.category.rawValue == "llm")
        #expect(plugin.metadata.stage.rawValue == "stable")
        #expect(plugin.metadata.policy.rawValue == "alwaysOn")
    }

    @Test("onBoot 注册唯一 MiniMax OpenAI 协议供应商")
    func pluginRegistersMiniMaxProvider() throws {
        let kernel = KernelCoreContainer()
        let manager = DefaultLLMManager()
        try kernel.registerProvider((any LLMManaging).self, manager)

        let plugin = MiniMaxProviderPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(manager.providerCount == 1)

        let info = try #require(manager.provider(id: "minimax-tokenplan")?.providerInfo)
        #expect(info.id == "minimax-tokenplan")
        #expect(info.displayName == "MiniMax")
        #expect(info.description == "MiniMax Token Plan via OpenAI-compatible API")
        #expect(info.defaultModel == "MiniMax-M2.7")
        #expect(info.apiFormat.rawValue == "openAI")
        #expect(info.apiKeyStorageKey == "DevAssistant_ApiKey_MiniMax")
        #expect(info.providerType.rawValue == "cloudService")
        #expect(info.websiteURL == URL(string: "https://platform.minimaxi.com/"))
    }

    @Test("MiniMax 共享模型清单完整有序")
    func miniMaxModelCatalog() throws {
        let provider = MiniMaxOpenAIProvider()
        let info = provider.providerInfo

        #expect(info.modelIDs == [
            "MiniMax-M3.1-Flash-Preview",
            "MiniMax-M3", "MiniMax-M2.7", "MiniMax-M2.7-highspeed",
            "MiniMax-M2.5", "MiniMax-M2.5-highspeed",
        ])
        #expect(info.models.count == 6)
        #expect(info.contains(model: info.defaultModel))

        // 三个协议变体共享同一批模型
        #expect(MiniMaxVendorModels.all.count == 6)
        #expect(MiniMaxVendorModels.all.map(\.id) == info.modelIDs)

        let flash = try #require(info.models.first(where: { $0.id == "MiniMax-M3.1-Flash-Preview" }))
        #expect(flash.contextWindowSize == 1_000_000)
        #expect(flash.supportsVision == true)
        let m3 = try #require(info.models.first(where: { $0.id == "MiniMax-M3" }))
        #expect(m3.contextWindowSize == 1_000_000)
        #expect(m3.supportsVision == true)
        let m25 = try #require(info.models.first(where: { $0.id == "MiniMax-M2.5" }))
        #expect(m25.contextWindowSize == 204_800)
        #expect(m25.supportsVision == false)
    }

    @Test("MiniMax 指向 minimaxi.com 端点")
    func miniMaxEndpointConfiguration() {
        let provider = MiniMaxOpenAIProvider()

        #expect(provider.providerID == "minimax-tokenplan")
        #expect(provider.openAIConfiguration?.baseURL == "https://api.minimaxi.com/v1/chat/completions")
    }

    @Test("MiniMax 支持远程模型源")
    func miniMaxUsesRemoteModelSource() throws {
        let provider = MiniMaxOpenAIProvider()

        #expect(provider.usesRemoteModelList == true)
        // 未拉取过时无同步时间
        #expect(provider.lastModelSyncDate == nil)
        // 远程未就绪时回退静态清单，默认模型仍可见
        #expect(provider.availableModels.contains { $0.id == provider.providerInfo.defaultModel })
    }

    @Test("远程模型列表解析只提取模型 id")
    func remoteModelListParsing() throws {
        let payload = """
        {"object":"list","data":[
          {"id":"MiniMax-M3","object":"model","created":1780272000,"owned_by":"minimax"},
          {"id":"MiniMax-M2.7","object":"model","created":1773799200,"owned_by":"minimax"},
          {"object":"model","created":1770948000,"owned_by":"minimax"},
          {"id":"","object":"model"}
        ]}
        """
        let models = try MiniMaxRemoteModelListLoader.parse(data: Data(payload.utf8))

        // 缺少 id 与空 id 的条目被丢弃
        #expect(models.map(\.id) == ["MiniMax-M3", "MiniMax-M2.7"])
        // 上游不提供上下文窗口与能力信息
        #expect(models.allSatisfy { $0.contextWindowSize == nil })
        #expect(models.allSatisfy { !$0.supportsVision })
    }

    @Test("远程列表解析失败时抛错而非返回空列表")
    func remoteModelListParsingRejectsInvalidPayload() {
        let missingData = Data(#"{"object":"list"}"#.utf8)
        #expect(throws: VendorAPIError.self) {
            _ = try MiniMaxRemoteModelListLoader.parse(data: missingData)
        }

        let brokenJSON = Data("not json".utf8)
        #expect(throws: VendorAPIError.self) {
            _ = try MiniMaxRemoteModelListLoader.parse(data: brokenJSON)
        }
    }

    @Test("合并策略保留静态元数据并追加远程新增模型")
    func remoteMergeKeepsStaticMetadata() throws {
        let base = MiniMaxVendorModels.all
        // 远程响应不带元数据；若按 id 覆盖会把上下文窗口与视觉能力清空
        let remote = [
            LLMModelInfo(id: "MiniMax-M3"),
            LLMModelInfo(id: "MiniMax-M4-Preview"),
        ]

        let merged = MiniMaxRemoteModelListLoader.merge(base: base, remote: remote)

        #expect(merged.count == base.count + 1)
        // 静态清单顺序不变，新增模型追加在末尾
        #expect(Array(merged.prefix(base.count).map(\.id)) == base.map(\.id))
        #expect(merged.last?.id == "MiniMax-M4-Preview")

        // 同 id 模型保留静态元数据
        let m3 = try #require(merged.first(where: { $0.id == "MiniMax-M3" }))
        #expect(m3.contextWindowSize == 1_000_000)
        #expect(m3.supportsVision == true)

        // 远程为空时等价于静态清单
        #expect(MiniMaxRemoteModelListLoader.merge(base: base, remote: []) == base)
    }

    @Test("onBoot 在缺少 LLM 管理器时不抛错")
    func onBootWithoutManagerDoesNotThrow() throws {
        let kernel = KernelCoreContainer()
        let plugin = MiniMaxProviderPlugin()

        #expect(throws: Never.self) { try plugin.onBoot(kernel: kernel) }
    }

    @Test("onShutdown 不抛错")
    func onShutdownDoesNotThrow() throws {
        let kernel = KernelCoreContainer()
        let manager = DefaultLLMManager()
        try kernel.registerProvider((any LLMManaging).self, manager)

        let plugin = MiniMaxProviderPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(throws: Never.self) { try plugin.onShutdown(kernel: kernel) }
    }
}
