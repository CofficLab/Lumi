import Foundation
import KernelCore
import ProviderLLMManager
import KitLLM
import Testing
@testable import PluginLLMProviderUITest

/// 验证桩经**真实**适配器链路后能产出预期结果。
///
/// 这是本包的核心保证：桩只替换了最底层字节传输，请求序列化、SSE 解析、
/// 增量累积全部走 `KitLLM` 的生产代码。这些测试因此锁住的不是桩自己，
/// 而是「桩 + 真实链路」的组合行为。
@MainActor
@Suite("UI 测试供应商")
struct UITestProviderTests {

    // MARK: - 元数据

    @Test("注册表 key 与本地类型标记稳定")
    func providerIdentityIsLocal() {
        let provider = UITestProvider()
        let info = provider.providerInfo

        #expect(info.id == "ui-test")
        #expect(provider.providerID == "ui-test")
        #expect(info.displayName == "UI Test")
        // 本地类型：模型选择器里归入「本地」分组，且不提示配置 API Key。
        #expect(info.isLocal)
        #expect(info.providerType == .local)
        #expect(info.apiFormat == .openAI)
    }

    @Test("默认模型是固定文本场景，且模型清单覆盖全部场景")
    func modelCatalogueCoversAllScenarios() {
        let info = UITestProvider().providerInfo

        #expect(info.defaultModel == UITestScenario.text.rawValue)
        #expect(info.defaultModel == "ui-test-text")
        #expect(info.contains(model: info.defaultModel))
        #expect(info.modelIDs == UITestScenario.allCases.map(\.rawValue))
    }

    @Test("供应商不声明远程模型源，刷新是无副作用的空操作")
    func hasNoRemoteModelList() async throws {
        let provider = UITestProvider(apiService: VendorAPIService(networkProvider: UITestStubNetwork()))
        #expect(provider.usesRemoteModelList == false)
        // 静态供应商的刷新不应发任何网络请求，也不应抛错。
        try await provider.refreshModels()
        #expect(provider.availableModels.count == UITestScenario.allCases.count)
    }

    @Test("API Key 为固定假串，且解析不触碰 Keychain")
    func resolvesStubAPIKeyWithoutKeychain() throws {
        let provider = UITestProvider()

        // 真实供应商在此处会读 Keychain 并在未配置时抛 missingAPIKey。
        #expect(try provider.resolveAPIKey() == "ui-test-key")
        #expect(provider.getApiKey() == "ui-test-key")
        #expect(provider.hasApiKey())
    }

    // MARK: - 端到端（真实适配器链路）

    @Test("文本场景经真实 SSE 解析后产出完整正文")
    func textScenarioStreamsExpectedReply() async throws {
        let provider = makeProvider()
        let collector = StreamCollector()

        let response = try await provider.streamComplete(
            request(text: .text),
            onChunk: { collector.append($0.content) }
        )

        #expect(collector.text == UITestFixtures.textResponse)
        #expect(collector.text == "UI Testing Reply")
        #expect(response.content == UITestFixtures.textResponse)
        #expect(response.inputTokenCount == 12)
        #expect(response.outputTokenCount == 6)
        #expect(collector.chunkCount > 1, "正文应分多个 chunk 增量到达")
    }

    @Test("非流式调用与流式调用产出同一正文")
    func nonStreamingMatchesStreaming() async throws {
        let provider = makeProvider()

        let streamed = try await provider.streamComplete(request(text: .text)) { _ in }
        let completed = try await provider.complete(request(text: .text))

        #expect(completed.content == streamed.content)
        #expect(completed.content == UITestFixtures.textResponse)
    }

    @Test("工具场景产出单个工具调用且 arguments 完整")
    func toolScenarioProducesCompleteToolCall() async throws {
        let provider = makeProvider()

        let response = try await provider.streamComplete(request(text: .tool)) { _ in }

        let call = try #require(response.toolCalls?.first)
        #expect(response.toolCalls?.count == 1)
        #expect(call.id == "call_ui_test_0001")
        #expect(call.name == UITestFixtures.toolName)
        // 分两片下发，累积器必须还原成完整 JSON。
        #expect(call.arguments == UITestFixtures.toolArguments)
        #expect(response.stopReason == "tool_calls")
    }

    @Test("错误场景在真实解析链路上抛出失败")
    func errorScenarioThrowsThroughRealParser() async throws {
        let provider = makeProvider()

        await #expect(throws: (any Error).self) {
            _ = try await provider.streamComplete(request(text: .error)) { _ in }
        }
    }

    @Test("长文本场景正文完整累积")
    func longScenarioStreamsEveryParagraph() async throws {
        let provider = makeProvider()
        let collector = StreamCollector()

        let response = try await provider.streamComplete(request(text: .long)) { chunk in
            collector.append(chunk.content)
        }

        let paragraphs = collector.text.split(separator: "。").filter { !$0.isEmpty }
        #expect(paragraphs.count == UITestFixtures.longParagraphCount)
        #expect(response.content == collector.text)
    }

    @Test("未知模型落到 unknown 场景而非崩溃或空响应")
    func unknownModelFallsBackSafely() async throws {
        let provider = makeProvider()
        let request = LLMRequest(
            conversationID: UUID(),
            providerID: nil,
            messages: [LLMMessage(role: .user, content: "hi")],
            model: "some-real-model",
            tools: nil,
            reasoningEffort: nil
        )

        let response = try await provider.streamComplete(request) { _ in }

        #expect(response.content == UITestFixtures.textResponse)
    }

    @Test("桩确实收到被真实序列化过的请求体")
    func stubSeesRealSerializedRequestBody() async throws {
        let stub = UITestStubNetwork()
        let provider = makeProvider(stub: stub)

        _ = try await provider.streamComplete(request(text: .tool)) { _ in }

        let body = try #require(stub.lastRequestBody)
        let object = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        // 若适配器没写 model 字段，桩会落到 unknown 场景，这里应能看到真实模型名。
        #expect(object["model"] as? String == "ui-test-tool")
        #expect(object["stream"] as? Bool == true)
        // 消息经真实序列化进 body，说明请求构建路径是生产代码。
        #expect((object["messages"] as? [[String: Any]])?.isEmpty == false)
    }

    // MARK: - Helper

    private func makeProvider(stub: UITestStubNetwork = UITestStubNetwork()) -> UITestProvider {
        UITestProvider(apiService: VendorAPIService(networkProvider: stub))
    }

    private func request(text scenario: UITestScenario) -> LLMRequest {
        LLMRequest(
            conversationID: UUID(),
            providerID: nil,
            messages: [LLMMessage(role: .user, content: "UI 测试提示")],
            model: scenario.rawValue,
            tools: nil,
            reasoningEffort: nil
        )
    }
}

// MARK: - Helper

/// 收集流式 chunk 的正文。
///
/// - Note: `onChunk` 是 `@Sendable` 闭包，不能直接改捕获的局部变量
///   （Swift 6 会报 `mutation of captured var in concurrently-executing code`），
///   因此用加锁的引用类型承接。
private final class StreamCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var buffer = ""
    private var chunks = 0

    func append(_ content: String?) {
        lock.withLock {
            if let content { buffer += content }
            chunks += 1
        }
    }

    var text: String {
        lock.withLock { buffer }
    }

    var chunkCount: Int {
        lock.withLock { chunks }
    }
}

// MARK: - 插件装配

#if DEBUG
@MainActor
@Suite("UI 测试供应商插件装配")
struct UITestProviderPluginTests {

    @Test("插件身份与元数据稳定")
    func pluginIdentityAndMetadata() {
        let plugin = PluginUITestProvider()

        #expect(plugin.id == "com.coffic.lumi.plugin.llm-provider.uitest")
        #expect(plugin.order == 900)
        #expect(plugin.metadata.category == .llm)
        #expect(plugin.metadata.stage == .experimental)
        // 默认停用：只能由启动参数驱动，避免有人手工启用一个永远返回假数据的供应商。
        #expect(plugin.metadata.policy == .disabled)
    }

    @Test("非 UI 测试启动时不注册供应商")
    func doesNotRegisterWithoutLaunchArgument() throws {
        let kernel = KernelCoreContainer()
        let manager = DefaultLLMManager()
        try kernel.registerProvider((any LLMManaging).self, manager)

        try PluginUITestProvider().onBoot(kernel: kernel)

        #expect(manager.provider(id: "ui-test") == nil)
    }

    @Test("onBoot 在缺少 LLM 管理器时不抛错")
    func onBootWithoutManagerDoesNotThrow() throws {
        let kernel = KernelCoreContainer()
        #expect(throws: Never.self) { try PluginUITestProvider().onBoot(kernel: kernel) }
    }
}
#endif
