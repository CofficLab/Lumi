import Foundation
import KitAgentTool
import KitLLM
import Testing
@testable import PluginAgentLoop

/// 工具 schema 构建与 token 估算的契约（Issue #1275）。
///
/// 两条核心要求：
/// 1. token 估算使用工具提供的规范化文本时，结果与「重新序列化」完全一致；
/// 2. schema 数组的组装不在主线程上同步执行。
@Suite("工具 schema 构建与 token 估算")
struct ToolSchemaBuildingTests {

    /// 测试用工具：可选择是否提供规范化 schema 文本。
    private struct SchemaTool: SuperAgentTool {
        let name: String
        let json: String
        /// 记录 `inputSchema` 被访问时是否在主线程上。
        let threadLog: ThreadLog?

        init(
            name: String = "demo.tool",
            json: String,
            threadLog: ThreadLog? = nil
        ) {
            self.name = name
            self.json = json
            self.threadLog = threadLog
        }

        func description(for language: LanguagePreference) -> String { "演示工具" }

        func inputSchema(for language: LanguagePreference) -> [String: Any] {
            threadLog?.record()
            let data = json.data(using: .utf8) ?? Data()
            return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        }

        func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .safe }

        func displayDescription(for arguments: [String: ToolArgument]) -> String { "演示工具" }
    }

    /// 实现 `NormalizedSchemaProviding` 的测试用工具。
    private struct NormalizedSchemaTool: SuperAgentTool, NormalizedSchemaProviding {
        let name: String
        let json: String

        func description(for language: LanguagePreference) -> String { "演示工具" }

        func inputSchema(for language: LanguagePreference) -> [String: Any] {
            let data = json.data(using: .utf8) ?? Data()
            return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        }

        func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .safe }

        func displayDescription(for arguments: [String: ToolArgument]) -> String { "演示工具" }

        var normalizedInputSchemaJSON: String? {
            let data = json.data(using: .utf8) ?? Data()
            guard
                let object = try? JSONSerialization.jsonObject(with: data),
                let sorted = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
            else { return nil }
            return String(data: sorted, encoding: .utf8)
        }
    }

    private let sampleJSON = #"{"type":"object","properties":{"a":{"type":"string","description":"说明"}},"required":["a"]}"#

    // MARK: - 规范化文本接入

    @Test("提供规范化文本的工具会带上它")
    func toolWithNormalizedTextCarriesIt() {
        let tool = NormalizedSchemaTool(name: "demo.tool", json: sampleJSON)
        let schema = LLMFunctionSchema(tool: tool, language: .english)

        #expect(schema.normalizedParametersJSON != nil)
    }

    @Test("未提供规范化文本的工具不带它")
    func toolWithoutNormalizedTextLeavesItNil() {
        let tool = SchemaTool(json: sampleJSON)
        let schema = LLMFunctionSchema(tool: tool, language: .english)

        #expect(schema.normalizedParametersJSON == nil)
    }

    @Test("规范化文本与直接序列化结果一致")
    func normalizedTextMatchesDirectSerialization() throws {
        let tool = NormalizedSchemaTool(name: "demo.tool", json: sampleJSON)
        let schema = LLMFunctionSchema(tool: tool, language: .english)

        let expected = String(
            data: try JSONSerialization.data(
                withJSONObject: schema.parameters,
                options: [.sortedKeys]
            ),
            encoding: .utf8
        )
        #expect(schema.normalizedParametersJSON == expected)
    }

    @Test("工具的 schema 参数与直接解析一致")
    func parametersMatchDirectParsing() throws {
        let tool = NormalizedSchemaTool(name: "demo.tool", json: sampleJSON)
        let schema = LLMFunctionSchema(tool: tool, language: .english)

        let expected = try #require(
            try? JSONSerialization.jsonObject(with: Data(sampleJSON.utf8)) as? [String: Any]
        )
        #expect(NSDictionary(dictionary: schema.parameters).isEqual(to: expected))
    }

    // MARK: - 估算结果不变

    @Test("带规范化文本时 token 估算结果与不带时完全相同")
    func tokenEstimateIsIdenticalWithAndWithoutNormalizedText() {
        let withNormalized = LLMFunctionSchema(
            tool: NormalizedSchemaTool(name: "demo.tool", json: sampleJSON),
            language: .english
        )
        let withoutNormalized = LLMFunctionSchema(
            tool: SchemaTool(name: "demo.tool", json: sampleJSON),
            language: .english
        )

        #expect(
            ToolSchemaBuilder.estimateTokens([withNormalized])
                == ToolSchemaBuilder.estimateTokens([withoutNormalized]),
            "规范化文本不得改变 token 估算结果"
        )
    }

    @Test("规范化文本与序列化路径的字节数一致")
    func normalizedAndSerializedByteCountsMatch() throws {
        let tool = NormalizedSchemaTool(name: "demo.tool", json: sampleJSON)
        let schema = LLMFunctionSchema(tool: tool, language: .english)

        let normalized = try #require(schema.normalizedParametersJSON)
        let serialized = ToolSchemaBuilder.jsonText(for: schema.parameters)
        #expect(normalized.utf8.count == serialized.utf8.count)
    }

    @Test("多个工具的估算结果等于各自估算之和")
    func tokenEstimateIsSumOfIndividualEstimates() {
        let first = LLMFunctionSchema(
            tool: NormalizedSchemaTool(name: "demo.a", json: sampleJSON),
            language: .english
        )
        let second = LLMFunctionSchema(
            tool: SchemaTool(name: "demo.b", json: sampleJSON),
            language: .english
        )

        #expect(
            ToolSchemaBuilder.estimateTokens([first, second])
                == ToolSchemaBuilder.estimateTokens([first]) + ToolSchemaBuilder.estimateTokens([second])
        )
    }

    @Test("畸形 schema 降级为文本估算而不崩溃")
    func malformedSchemaFallsBackToTextEstimation() {
        // 非 JSON 类型（闭包）会让 JSONSerialization 抛 ObjC 异常，
        // 必须先降级，不能让回合崩溃。
        let schema = LLMFunctionSchema(
            name: "demo.bad",
            description: "坏 schema",
            parameters: ["type": "object", "bad": { }]
        )

        let tokens = ToolSchemaBuilder.estimateTokens([schema])
        #expect(tokens > 0)
    }

    // MARK: - 离主线程组装

    @MainActor
    @Test("schema 数组的组装不在主线程上执行")
    func schemaBuildingRunsOffMainThread() async {
        // 大量工具，让组装成为可观测的主线程占用。
        let log = ThreadLog()
        let tools: [any SuperAgentTool] = (0..<50).map { index in
            SchemaTool(name: "demo.tool_\(index)", json: sampleJSON, threadLog: log)
        }

        _ = await ToolSchemaBuilder.buildSchemas(tools, language: .english)

        #expect(log.accessCount == 50, "每个工具的 schema 都应被读取")
        #expect(log.sawMainThread == false, "schema 组装不得在主线程上执行")
    }

    @MainActor
    @Test("离主线程组装的 schema 与逐个组装完全一致")
    func offMainActorSchemasMatchSequentialBuild() async {
        let tools: [any SuperAgentTool] = (0..<20).map { index in
            SchemaTool(name: "demo.tool_\(index)", json: sampleJSON)
        }

        let built = await ToolSchemaBuilder.buildSchemas(tools, language: .english)
        let expected = tools.map { LLMFunctionSchema(tool: $0, language: .english) }

        #expect(built.count == expected.count)
        for (left, right) in zip(built, expected) {
            #expect(left.name == right.name)
            #expect(left.description == right.description)
            #expect(NSDictionary(dictionary: left.parameters)
                .isEqual(to: right.parameters))
        }
    }
}

/// 记录工具 `inputSchema` 被访问时的线程归属。
private final class ThreadLog: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    private var mainThread = false

    /// 被访问的次数。
    var accessCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }

    /// 访问过程中是否出现在主线程上。
    var sawMainThread: Bool {
        lock.lock()
        defer { lock.unlock() }
        return mainThread
    }

    func record() {
        lock.lock()
        count += 1
        if pthread_main_np() != 0 {
            mainThread = true
        }
        lock.unlock()
    }
}
