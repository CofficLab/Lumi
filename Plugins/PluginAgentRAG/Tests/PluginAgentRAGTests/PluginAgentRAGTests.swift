import AgentToolKit
import Foundation
import Testing
@testable import PluginAgentRAG

@Test func packageLoads() async throws {
    #expect(true)
}

@Test func keywordSearchFindsUTF16SourceFiles() async throws {
    let projectURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("PluginAgentRAGTests")
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
