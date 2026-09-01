import Foundation
import KernelCore
import KitLLM
import ProviderLLMManager
import Testing
@testable import PluginLLMProviderOpenCode

@MainActor
struct OpenCodeProviderPluginTests {

    @Test("onBoot 把 Go 供应商注册进管理器")
    func pluginRegistersProviders() throws {
        let kernel = KernelCoreContainer()
        let manager = DefaultLLMProviderManagerProviding()
        try kernel.registerProvider((any LLMManaging).self, manager)

        let plugin = OpenCodeProviderPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(manager.providerCount == 1)
        #expect(manager.provider(id: "opencode-go")?.providerInfo.id == "opencode-go")
    }

    @Test("Go 流式工具调用必须收到终止信号，否则返回不完整流错误")
    func goProviderRejectsIncompleteToolCallStream() async throws {
        let network = StreamingNetworkStub(events: [toolCallEvent(arguments: #"{"path":"/tmp/a","#)])
        let service = VendorAPIService(networkProvider: network, maxAttempts: 1)
        let provider = GoProvider(apiService: service)
        VendorAPIKeyTools.set("sk-test-opencode-go", storageKey: "DevAssistant_ApiKey_OpenCodeGo")
        defer { VendorAPIKeyTools.remove(storageKey: "DevAssistant_ApiKey_OpenCodeGo") }

        do {
            _ = try await provider.streamComplete(
                LLMRequest(messages: [LLMMessage(role: .user, content: "写文件")], model: "deepseek-v4-flash"),
                onChunk: { _ in }
            )
            Issue.record("未收到终止信号的流不应返回成功")
        } catch let error as VendorAPIError {
            #expect(error == .incompleteStream)
        }
    }

    @Test("Go 流式工具调用会拼接分片并等待 finish_reason")
    func goProviderReconstructsFragmentedToolCall() async throws {
        let network = StreamingNetworkStub(events: [
            toolCallEvent(arguments: #"{"path":"/tmp/a",""#),
            toolCallEvent(arguments: #"content":"ok"}"#, includeIdentity: false),
            finishEvent(reason: "tool_calls"),
        ])
        let service = VendorAPIService(networkProvider: network, maxAttempts: 1)
        let provider = GoProvider(apiService: service)
        VendorAPIKeyTools.set("sk-test-opencode-go", storageKey: "DevAssistant_ApiKey_OpenCodeGo")
        defer { VendorAPIKeyTools.remove(storageKey: "DevAssistant_ApiKey_OpenCodeGo") }

        let response = try await provider.streamComplete(
            LLMRequest(messages: [LLMMessage(role: .user, content: "写文件")], model: "deepseek-v4-flash"),
            onChunk: { _ in }
        )

        #expect(response.toolCalls?.count == 1)
        #expect(response.toolCalls?.first?.arguments == #"{"path":"/tmp/a","content":"ok"}"#)
    }
}

private final class StreamingNetworkStub: LLMNetworkProviding, @unchecked Sendable {
    let events: [Data]

    init(events: [Data]) {
        self.events = events
    }

    func send(request: URLRequest, body: Data) async throws -> (Data, URLResponse) {
        throw StubError.unexpectedNonStreamingRequest
    }

    func stream(
        request: URLRequest,
        body: Data,
        onEvent: @Sendable @escaping (Data) async -> Bool
    ) async throws {
        for event in events where await onEvent(event) == false {
            break
        }
    }
}

private enum StubError: Error {
    case unexpectedNonStreamingRequest
}

private func toolCallEvent(arguments: String, includeIdentity: Bool = true) -> Data {
    var function: [String: Any] = ["arguments": arguments]
    if includeIdentity {
        function["name"] = "write_file"
    }
    var call: [String: Any] = [
        "index": 0,
        "type": "function",
        "function": function,
    ]
    if includeIdentity {
        call["id"] = "call-1"
    }
    let payload: [String: Any] = [
        "choices": [[
            "delta": ["tool_calls": [call]],
        ]],
    ]
    return sseData(payload)
}

private func finishEvent(reason: String) -> Data {
    sseData([
        "choices": [[
            "delta": [:],
            "finish_reason": reason,
        ]],
    ])
}

private func sseData(_ payload: [String: Any]) -> Data {
    let json = try! JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
    return Data("data: \(String(decoding: json, as: UTF8.self))\n\n".utf8)
}
