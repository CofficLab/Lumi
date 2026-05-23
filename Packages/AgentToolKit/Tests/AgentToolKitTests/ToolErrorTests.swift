import Foundation
import Testing
@testable import AgentToolKit

struct ToolErrorTests {
    @Test
    func toolNotFoundIncludesToolName() {
        let error = ToolError.toolNotFound("missing_tool")
        #expect(error.errorDescription == "Tool 'missing_tool' not found")
    }

    @Test
    func toolExecutionFailedIncludesUnderlyingDescription() {
        struct SampleError: LocalizedError {
            var errorDescription: String? { "boom" }
        }

        let error = ToolError.toolExecutionFailed("shell", SampleError())
        #expect(error.errorDescription == "Tool 'shell' execution failed: boom")
    }
}

struct ToolExecutionErrorTests {
    @Test
    func toolNotFoundDescription() {
        let error = ToolExecutionError.toolNotFound(toolName: "read_file")
        #expect(error.errorDescription == "Tool 'read_file' not found.")
    }

    @Test
    func executionFailedDescription() {
        let error = ToolExecutionError.executionFailed(toolName: "write_file", reason: "disk full")
        #expect(error.errorDescription == "Failed to execute 'write_file': disk full")
    }

    @Test
    func permissionDeniedDescription() {
        let error = ToolExecutionError.permissionDenied(toolName: "shell")
        #expect(error.errorDescription == "Permission denied for 'shell'")
    }
}
