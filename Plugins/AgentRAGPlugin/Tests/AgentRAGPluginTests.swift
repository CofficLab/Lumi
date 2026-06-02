import AgentToolKit
import Foundation
import Testing
@testable import AgentRAGPlugin

@Test func packageLoads() async throws {
    #expect(true)
}

@Test func searchCodeSchemaDeclaresBoundedControls() throws {
    let schema = RAGCodeSearchTool().inputSchema(for: .english)
    let properties = try #require(schema["properties"] as? [String: [String: Any]])

    #expect(properties["topK"]?["type"] as? String == "integer")
    #expect(properties["topK"]?["minimum"] as? Int == RAGCodeSearchTool.minTopK)
    #expect(properties["topK"]?["maximum"] as? Int == RAGCodeSearchTool.maxTopK)
    #expect(properties["timeout"]?["type"] as? String == "integer")
    #expect(properties["timeout"]?["minimum"] as? Int == Int(RAGCodeSearchTool.minTimeoutSeconds))
    #expect(properties["timeout"]?["maximum"] as? Int == Int(RAGCodeSearchTool.maxTimeoutSeconds))
}

@Test func searchCodeNormalizesUserControlledBounds() {
    #expect(RAGCodeSearchTool.normalizedTopK(nil) == RAGCodeSearchTool.defaultTopK)
    #expect(RAGCodeSearchTool.normalizedTopK(-10) == RAGCodeSearchTool.minTopK)
    #expect(RAGCodeSearchTool.normalizedTopK(12) == 12)
    #expect(RAGCodeSearchTool.normalizedTopK(999) == RAGCodeSearchTool.maxTopK)
    #expect(RAGCodeSearchTool.normalizedTimeout(nil) == RAGCodeSearchTool.defaultTimeoutSeconds)
    #expect(RAGCodeSearchTool.normalizedTimeout(0) == RAGCodeSearchTool.minTimeoutSeconds)
    #expect(RAGCodeSearchTool.normalizedTimeout(30) == 30)
    #expect(RAGCodeSearchTool.normalizedTimeout(999) == RAGCodeSearchTool.maxTimeoutSeconds)
}

@Test func keywordSearchFindsUTF16SourceFiles() async throws {
    let projectURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("AgentRAGPluginTests")
        .appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: projectURL) }

    let fileURL = projectURL.appendingPathComponent("Sources/UTF16Searchable.swift")
    try FileManager.default.createDirectory(
        at: fileURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try """
    struct UTF16Searchable {
        let marker = "needle utf16 keyword target"
    }
    """.write(to: fileURL, atomically: true, encoding: .utf16)

    let context = ToolExecutionContext(
        conversationId: UUID(),
        toolCallId: "test-search-code",
        toolName: "search_code",
        currentProjectPath: projectURL.path,
        allowedDirectories: [projectURL.path]
    )
    let output = try await RAGCodeSearchTool().execute(
        arguments: [
            "query": ToolArgument("needle utf16 keyword target"),
            "mode": ToolArgument("keyword"),
            "projectPath": ToolArgument(projectURL.path),
        ],
        context: context
    )

    #expect(output.contains("UTF16Searchable.swift"))
    #expect(output.contains("needle utf16 keyword target"))
}

@Test func keywordSearchClampsOversizedTopK() async throws {
    let projectURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("AgentRAGPluginTests")
        .appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: projectURL) }

    let sourcesURL = projectURL.appendingPathComponent("Sources", isDirectory: true)
    try FileManager.default.createDirectory(at: sourcesURL, withIntermediateDirectories: true)
    for index in 1...25 {
        let fileURL = sourcesURL.appendingPathComponent("Match\(index).swift")
        try """
        struct Match\(index) {
            let marker = "bounded topk target"
        }
        """.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    let context = ToolExecutionContext(
        conversationId: UUID(),
        toolCallId: "test-search-code-topk",
        toolName: "search_code",
        currentProjectPath: projectURL.path,
        allowedDirectories: [projectURL.path]
    )
    let output = try await RAGCodeSearchTool().execute(
        arguments: [
            "query": ToolArgument("bounded topk target"),
            "mode": ToolArgument("keyword"),
            "projectPath": ToolArgument(projectURL.path),
            "topK": ToolArgument(999),
        ],
        context: context
    )

    #expect(output.contains("Results: \(RAGCodeSearchTool.maxTopK)"))
    #expect(!output.contains("### \(RAGCodeSearchTool.maxTopK + 1)."))
}

@Test func processCaptureHandlesLargeStdoutWithoutPipeBackpressure() async throws {
    let result = try RAGCodeSearchTool.runProcessCapturingStdout(
        executableURL: URL(fileURLWithPath: "/bin/sh"),
        arguments: [
            "-c",
            """
            i=1
            while [ "$i" -le 300 ]; do
              printf 'rag-grep-%03d-%0512d\\n' "$i" 0
              i=$((i + 1))
            done
            """
        ],
        timeout: 5
    )

    let output = String(data: result?.stdout ?? Data(), encoding: .utf8) ?? ""
    #expect(result?.terminationStatus == 0)
    #expect(output.contains("rag-grep-300-"))
    #expect((result?.stdout.count ?? 0) > 150_000)
}
