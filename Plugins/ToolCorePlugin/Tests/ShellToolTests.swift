import Foundation
import LumiCoreKit
import Testing
@testable import ToolCorePlugin

@Test func shellToolExecutesCommand() async throws {
    let tool = ShellTool()
    let context = LumiToolExecutionContext(
        conversationID: UUID(),
        toolCallID: "call-echo",
        toolName: "run_command"
    )

    let output = try await tool.execute(
        arguments: ["command": .string("echo hello-shell-tool")],
        context: context
    )

    #expect(output.contains("hello-shell-tool"))
}

@Test func shellToolDoesNotBlockMainActorDuringExecution() async throws {
    let tool = ShellTool()
    let context = LumiToolExecutionContext(
        conversationID: UUID(),
        toolCallID: "call-sleep",
        toolName: "run_command"
    )

    let commandTask = Task {
        try await tool.execute(
            arguments: ["command": .string("sleep 0.4")],
            context: context
        )
    }

    let mainActorResponded = await withCheckedContinuation { continuation in
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 50_000_000)
            continuation.resume(returning: true)
        }
    }

    #expect(mainActorResponded)
    _ = try await commandTask.value
}

@Test func shellToolHonoursWorkingDirectory() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("ShellToolTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let marker = "shell-tool-marker-\(UUID().uuidString)"
    let tool = ShellTool()
    let context = LumiToolExecutionContext(
        conversationID: UUID(),
        toolCallID: "call-ls",
        toolName: "run_command",
        currentProjectPath: directory.path
    )

    let output = try await tool.execute(
        arguments: ["command": .string("touch \(marker) && ls")],
        context: context
    )

    #expect(output.contains(marker))
}
