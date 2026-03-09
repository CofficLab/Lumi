#if canImport(XCTest)
import XCTest
@testable import Lumi

final class MultiAgentCollaborationTests: XCTestCase {

    func testSingleWorkerTaskExecution() async throws {
        let llm = MockWorkerLLMService(
            responses: [
                ChatMessage(role: .assistant, content: "Code analysis complete.")
            ]
        )
        let tools = MockWorkerToolService()
        let manager = WorkerAgentManager(llmService: llm)

        let result = try await manager.executeTask(
            type: .codeExpert,
            task: "Analyze the repository structure",
            config: sampleConfig(),
            toolService: tools
        )

        XCTAssertEqual(result, "Code analysis complete.")
        let firstCallCount = await llm.callCount
        XCTAssertEqual(firstCallCount, 1)
    }

    func testSequentialMultiWorkerExecution() async throws {
        let llm = MockWorkerLLMService(
            responses: [
                ChatMessage(role: .assistant, content: "Project architecture summary."),
                ChatMessage(role: .assistant, content: "Documentation draft created.")
            ]
        )
        let tools = MockWorkerToolService()
        let manager = WorkerAgentManager(llmService: llm)

        let analysis = try await manager.executeTask(
            type: .architect,
            task: "Analyze architecture",
            config: sampleConfig(),
            toolService: tools
        )
        let doc = try await manager.executeTask(
            type: .documentExpert,
            task: "Write technical documentation",
            config: sampleConfig(),
            toolService: tools
        )

        XCTAssertEqual(analysis, "Project architecture summary.")
        XCTAssertEqual(doc, "Documentation draft created.")
        let secondCallCount = await llm.callCount
        XCTAssertEqual(secondCallCount, 2)
    }

    func testWorkerFailurePropagates() async {
        let llm = MockWorkerLLMService(
            responses: [],
            errorToThrow: NSError(domain: "test", code: 500, userInfo: [NSLocalizedDescriptionKey: "Mock failure"])
        )
        let tools = MockWorkerToolService()
        let manager = WorkerAgentManager(llmService: llm)

        do {
            _ = try await manager.executeTask(
                type: .testExpert,
                task: "Generate tests",
                config: sampleConfig(),
                toolService: tools
            )
            XCTFail("Expected executeTask to throw")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("Mock failure"))
        }
    }

    func testWorkerToolCallRoundtrip() async throws {
        let toolCall = ToolCall(id: "call_1", name: "mock_tool", arguments: "{\"value\":\"x\"}")
        let llm = MockWorkerLLMService(
            responses: [
                ChatMessage(role: .assistant, content: "", toolCalls: [toolCall]),
                ChatMessage(role: .assistant, content: "Tool output consumed.")
            ]
        )
        let tools = MockWorkerToolService(
            tools: [MockAgentTool(name: "mock_tool")],
            toolResults: ["mock_tool": "mock_result"]
        )
        let service = WorkerAgentService(llmService: llm, toolService: tools)
        let worker = WorkerAgent(
            name: "代码专家",
            type: .codeExpert,
            description: "test",
            specialty: "test",
            config: sampleConfig(),
            systemPrompt: "You are a code worker"
        )

        let result = try await service.execute(worker: worker, task: "Run tool")
        XCTAssertEqual(result, "Tool output consumed.")
        let toolCallCount = await llm.callCount
        XCTAssertEqual(toolCallCount, 2)
        XCTAssertEqual(tools.executedToolNames, ["mock_tool"])
    }

    private func sampleConfig() -> LLMConfig {
        LLMConfig(apiKey: "test-key", model: "test-model", providerId: "anthropic")
    }
}

private actor MockWorkerLLMService: WorkerLLMServiceProtocol {
    private var responses: [ChatMessage]
    private let errorToThrow: Error?
    private(set) var callCount: Int = 0

    init(responses: [ChatMessage], errorToThrow: Error? = nil) {
        self.responses = responses
        self.errorToThrow = errorToThrow
    }

    func sendMessage(
        messages: [ChatMessage],
        config: LLMConfig,
        tools: [AgentTool]?
    ) async throws -> ChatMessage {
        callCount += 1
        if let errorToThrow {
            throw errorToThrow
        }
        guard !responses.isEmpty else {
            return ChatMessage(role: .assistant, content: "No mock response")
        }
        return responses.removeFirst()
    }
}

private final class MockWorkerToolService: WorkerToolServiceProtocol, @unchecked Sendable {
    let tools: [AgentTool]
    private let toolResults: [String: String]
    private let permissionedTools: Set<String>
    private(set) var executedToolNames: [String] = []

    init(
        tools: [AgentTool] = [],
        toolResults: [String: String] = [:],
        permissionedTools: Set<String> = []
    ) {
        self.tools = tools
        self.toolResults = toolResults
        self.permissionedTools = permissionedTools
    }

    func requiresPermission(toolName: String, argumentsJSON: String?) -> Bool {
        permissionedTools.contains(toolName)
    }

    func executeTool(named name: String, argumentsJSON: String) async throws -> String {
        executedToolNames.append(name)
        if let output = toolResults[name] {
            return output
        }
        return "mock_output"
    }
}

private struct MockAgentTool: AgentTool {
    let name: String
    let description: String = "mock tool"
    var inputSchema: [String: Any] { [:] }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        "mock_output"
    }
}
#endif
