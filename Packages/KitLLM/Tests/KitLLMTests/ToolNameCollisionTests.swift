import Foundation
import Testing
@testable import KitLLM

/// 工具名 sanitize 撞名时的丢弃策略（#179）。
///
/// `a.b` 与 `a_b` 都会 sanitize 成 `a_b`：重复的 function name 会被供应商
/// 拒绝，或让模型把调用路由到先注册的工具。`toolSchemas(from:)` 是全部
/// 四条请求路径（OpenAI / Anthropic × 流式 / 非流式，含 GoProvider 的
/// Responses 路由）构建 tools 与 reverseMap 的唯一入口，撞名丢弃在这
/// 一层生效后，下游请求体不可能再出现重复名。
@Suite("工具名 sanitize 撞名丢弃")
struct ToolNameCollisionTests {

    @Test("撞名工具只保留先注册者，reverseMap 指向先注册者")
    @MainActor
    func toolSchemasDropsCollidingTools() throws {
        let provider = CollisionTestProvider()
        let schemas = [
            LLMFunctionSchema(name: "a.b", description: "first", parameters: ["type": "object"]),
            LLMFunctionSchema(name: "a_b", description: "collides with a.b", parameters: ["type": "object"]),
            LLMFunctionSchema(name: "other.tool", description: "distinct", parameters: ["type": "object"]),
        ]

        let (tools, reverseMap) = provider.toolSchemas(from: schemas)

        let names = try #require(tools?.map(\.name))
        #expect(names == ["a.b", "other.tool"])
        #expect(reverseMap == ["a_b": "a.b", "other_tool": "other.tool"])
    }

    @Test("OpenAI 非流式请求体不含重复工具名")
    @MainActor
    func openAINonStreamingBodyHasUniqueToolNames() async throws {
        let body = try await collisionRequestBody(
            streaming: false,
            anthropic: false
        )
        let names = try #require((body["tools"] as? [[String: Any]])?.compactMap {
            ($0["function"] as? [String: Any])?["name"] as? String
        })
        #expect(names.count == Set(names).count)
        #expect(names == ["a_b", "other_tool"])
    }

    @Test("OpenAI 流式请求体不含重复工具名")
    @MainActor
    func openAIStreamingBodyHasUniqueToolNames() async throws {
        let body = try await collisionRequestBody(
            streaming: true,
            anthropic: false
        )
        let names = try #require((body["tools"] as? [[String: Any]])?.compactMap {
            ($0["function"] as? [String: Any])?["name"] as? String
        })
        #expect(names.count == Set(names).count)
        #expect(names == ["a_b", "other_tool"])
    }

    @Test("Anthropic 非流式请求体不含重复工具名")
    @MainActor
    func anthropicNonStreamingBodyHasUniqueToolNames() async throws {
        let body = try await collisionRequestBody(
            streaming: false,
            anthropic: true
        )
        let names = try #require((body["tools"] as? [[String: Any]])?.compactMap { $0["name"] as? String })
        #expect(names.count == Set(names).count)
        #expect(names == ["a_b", "other_tool"])
    }

    @Test("Anthropic 流式请求体不含重复工具名")
    @MainActor
    func anthropicStreamingBodyHasUniqueToolNames() async throws {
        let body = try await collisionRequestBody(
            streaming: true,
            anthropic: true
        )
        let names = try #require((body["tools"] as? [[String: Any]])?.compactMap { $0["name"] as? String })
        #expect(names.count == Set(names).count)
        #expect(names == ["a_b", "other_tool"])
    }

    /// 走真实请求路径：`toolSchemas` 撞名丢弃后交给请求体构建器。
    @MainActor
    private func collisionRequestBody(streaming: Bool, anthropic: Bool) async throws -> [String: Any] {
        let provider = CollisionTestProvider()
        let schemas = [
            LLMFunctionSchema(name: "a.b", description: "first", parameters: ["type": "object"]),
            LLMFunctionSchema(name: "a_b", description: "collides with a.b", parameters: ["type": "object"]),
            LLMFunctionSchema(name: "other.tool", description: "distinct", parameters: ["type": "object"]),
        ]
        let (tools, _) = provider.toolSchemas(from: schemas)
        let config = LLMConfig(model: "test-model", providerId: "test")
        let messages = [LLMMessage(role: .user, content: "hi")]

        let data: Data
        if anthropic {
            let configuration = AnthropicCompatibleProviderConfiguration(baseURL: "https://example.com")
            data = streaming
                ? try await RequestBodyBuilder.anthropicStreamingBody(
                    messages: messages, model: "test-model", tools: tools, config: config, configuration: configuration)
                : try await RequestBodyBuilder.anthropicBody(
                    messages: messages, model: "test-model", tools: tools, config: config, configuration: configuration)
        } else {
            let configuration = OpenAICompatibleProviderConfiguration(baseURL: "https://example.com")
            data = streaming
                ? try await RequestBodyBuilder.openAIStreamingBody(
                    messages: messages, model: "test-model", tools: tools, config: config, configuration: configuration)
                : try await RequestBodyBuilder.openAIBody(
                    messages: messages, model: "test-model", tools: tools, config: config, configuration: configuration)
        }
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}

/// 最小供应商测试替身，仅用于调用 `toolSchemas(from:)`。
@MainActor
private final class CollisionTestProvider: VendorLLMProvider {
    init() {
        super.init(info: LLMProviderInfo(
            id: "collision-test",
            displayName: "Collision Test",
            defaultModel: "test-model",
            models: [LLMModelInfo(id: "test-model")]
        ))
    }
}
