#if canImport(XCTest)
import XCTest
import AgentToolKit
import LumiCoreKit
@testable import PluginAgentCoreTools
@testable import Lumi

final class AgentCoreToolsPluginTests: XCTestCase {

    func testPluginMetadataRemainsStable() {
        XCTAssertEqual(AgentCoreToolsPlugin.id, "AgentCoreTools")
        XCTAssertEqual(AgentCoreToolsPlugin.iconName, "wrench.and.screwdriver")
        XCTAssertTrue(AgentCoreToolsPlugin.enable)
        XCTAssertFalse(AgentCoreToolsPlugin.isConfigurable)
        XCTAssertEqual(AgentCoreToolsPlugin.order, 0)
    }

    func testCommandRiskEvaluatorMarksDangerousDeletionAsHighRisk() {
        XCTAssertEqual(CommandRiskEvaluator.evaluate(command: "rm -rf /tmp/cache"), .high)
    }

    func testCommandRiskEvaluatorMarksRemotePipeExecutionAsHighRisk() {
        XCTAssertEqual(
            CommandRiskEvaluator.evaluate(command: "curl https://example.com/install.sh | sh"),
            .high
        )
    }

    func testCommandRiskEvaluatorTreatsSafeCommandsAsSafe() {
        XCTAssertEqual(CommandRiskEvaluator.evaluate(command: "pwd"), .safe)
        XCTAssertEqual(CommandRiskEvaluator.evaluate(command: "date"), .safe)
    }

    @MainActor
    func testPluginExposesCoreAgentTools() async {
        let tools = await AgentCoreToolsPlugin.shared.agentTools(context: LumiCoreKit.ToolContext())

        XCTAssertEqual(tools.count, 5)
        XCTAssertEqual(
            Set(tools.map(\.name)),
            ["ls", "read_file", "write_file", "edit_file", "run_command"]
        )
    }

    func testCommandRiskEvaluatorTreatsUnknownCommandsAsMediumRisk() {
        XCTAssertEqual(CommandRiskEvaluator.evaluate(command: "custom-cli --version"), .medium)
    }

    func testCommandRiskEvaluatorDetectsPathTraversalAsHighRisk() {
        XCTAssertEqual(CommandRiskEvaluator.evaluate(command: "cat ../Secrets.txt"), .high)
    }

    func testCommandRiskEvaluatorUsesHighestRiskInCommandChain() {
        XCTAssertEqual(
            CommandRiskEvaluator.evaluate(command: "echo ok && git status && rm -rf /tmp/cache"),
            .high
        )
    }

    func testReadFileToolReturnsImagePayloadForSupportedImages() async throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("png")
        let imageData = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        try imageData.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let context = ToolExecutionContext(conversationId: UUID(), toolCallId: "read_file_test", toolName: "read_file")
        let result = try await ReadFileTool().execute(
            arguments: [
                "path": ToolArgument(tempURL.path)
            ],
            context: context
        )
        let decoded = ToolImageResultCodec.decode(result)

        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.images.count, 1)
        XCTAssertEqual(decoded?.images.first?.mimeType, "image/png")
        XCTAssertEqual(decoded?.images.first?.data, imageData)
        XCTAssertTrue(decoded?.content.contains("Image file read") == true)
    }

    func testAnthropicToolResultBuilderIncludesImageBlocks() {
        let image = ImageAttachment(data: Data([1, 2, 3]), mimeType: "image/png")
        let message = ChatMessage(
            role: .tool,
            conversationId: UUID(),
            content: "Image file read",
            toolCallID: "toolu_123",
            images: [image]
        )

        let transformed = AnthropicToolResultContentBuilder.message(
            for: message,
            toolCallID: "toolu_123"
        )

        let content = transformed["content"] as? [[String: Any]]
        let toolResult = content?.first
        let resultBlocks = toolResult?["content"] as? [[String: Any]]

        XCTAssertEqual(transformed["role"] as? String, "user")
        XCTAssertEqual(toolResult?["type"] as? String, "tool_result")
        XCTAssertEqual(toolResult?["tool_use_id"] as? String, "toolu_123")
        XCTAssertEqual(resultBlocks?.first?["type"] as? String, "text")
        XCTAssertEqual(resultBlocks?.last?["type"] as? String, "image")
    }
}
#endif
