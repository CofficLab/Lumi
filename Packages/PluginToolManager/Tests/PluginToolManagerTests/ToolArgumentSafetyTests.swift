import Foundation
import KitAgentTool
import KitShell
import ProviderToolManager
import Testing
@testable import PluginToolManager

/// 工具参数整型安全回归测试。
///
/// 工具参数来自 `JSONSerialization`：能放进 `Int` 的数字会以 `Int` 出现，
/// 放不进去的数字（`1e100`、`2^63`、`inf`、`nan`）会以 `Double` 出现。
/// 旧实现直接 `Int(double)`，越界时触发 Swift 运行时陷阱，进程当场退出。
/// 这些用例在修复前至少有一条会真的 trap。
@MainActor
private func withTempFile(
    lineCount: Int,
    _ body: (String) async throws -> Void
) async throws {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("lumi-arg-safety-\(UUID().uuidString).txt")
    let text = (1...lineCount).map { "line \($0)" }.joined(separator: "\n")
    try text.write(to: url, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: url) }
    try await body(url.path)
}

@MainActor
@Test func readFileRejectsOutOfRangeLimitFromJSON() async throws {
    try await withTempFile(lineCount: 5) { path in
        let tool = ReadFileTool()
        let arguments = try ToolArgumentCoding.decode("{\"path\":\"\(path)\",\"limit\":1e100}")
        await #expect(throws: ToolExecutionError.self) {
            _ = try await tool.execute(arguments: arguments)
        }
    }
}

@MainActor
@Test func readFileRejectsLimitAboveIntMaxFromJSON() async throws {
    try await withTempFile(lineCount: 5) { path in
        let tool = ReadFileTool()
        let arguments = try ToolArgumentCoding.decode(
            "{\"path\":\"\(path)\",\"limit\":9223372036854775808}"
        )
        await #expect(throws: ToolExecutionError.self) {
            _ = try await tool.execute(arguments: arguments)
        }
    }
}

@MainActor
@Test func readFileRejectsNonFiniteLimit() async throws {
    try await withTempFile(lineCount: 5) { path in
        let tool = ReadFileTool()
        for limit in [Double.infinity, Double.nan, -Double.infinity] {
            await #expect(throws: ToolExecutionError.self) {
                _ = try await tool.execute(arguments: [
                    "path": ToolArgument(path),
                    "limit": ToolArgument(limit),
                ])
            }
        }
    }
}

@MainActor
@Test func readFileRejectsNegativeLimitInsteadOfTrapping() async throws {
    try await withTempFile(lineCount: 5) { path in
        let tool = ReadFileTool()
        await #expect(throws: ToolExecutionError.self) {
            _ = try await tool.execute(arguments: [
                "path": ToolArgument(path),
                "limit": ToolArgument(-1),
            ])
        }
    }
}

@MainActor
@Test func readFileRejectsZeroLimit() async throws {
    try await withTempFile(lineCount: 5) { path in
        let tool = ReadFileTool()
        await #expect(throws: ToolExecutionError.self) {
            _ = try await tool.execute(arguments: [
                "path": ToolArgument(path),
                "limit": ToolArgument(0),
            ])
        }
    }
}

@MainActor
@Test func readFileCapsRepresentableOversizedLimit() async throws {
    try await withTempFile(lineCount: 300) { path in
        let tool = ReadFileTool()
        let result = try await tool.execute(arguments: [
            "path": ToolArgument(path),
            "limit": ToolArgument(10_000_000_000),
        ])
        #expect(result.contains("250\tline 250"))
        #expect(!result.contains("251\tline 251"))
        #expect(result.contains("use offset/limit to read more"))
    }
}

@MainActor
@Test func readFileAcceptsLimitLargerThanFileLength() async throws {
    try await withTempFile(lineCount: 5) { path in
        let tool = ReadFileTool()
        let result = try await tool.execute(arguments: [
            "path": ToolArgument(path),
            "limit": ToolArgument(1_000),
        ])
        #expect(result == "1\tline 1\n2\tline 2\n3\tline 3\n4\tline 4\n5\tline 5")
    }
}

@MainActor
@Test func readFileReportsOffsetBeyondEndOfFile() async throws {
    try await withTempFile(lineCount: 5) { path in
        let tool = ReadFileTool()
        await #expect(throws: ToolExecutionError.self) {
            _ = try await tool.execute(arguments: [
                "path": ToolArgument(path),
                "offset": ToolArgument(100),
            ])
        }
    }
}

@MainActor
@Test func readFileRejectsUnrepresentableOffset() async throws {
    try await withTempFile(lineCount: 5) { path in
        let tool = ReadFileTool()
        await #expect(throws: ToolExecutionError.self) {
            _ = try await tool.execute(arguments: [
                "path": ToolArgument(path),
                "offset": ToolArgument(1e100),
            ])
        }
    }
}

/// `Int.min` 作为负 offset 时，旧实现的 `totalLines + offset` 会整数溢出 trap。
@MainActor
@Test func readFileHandlesIntMinOffsetWithoutOverflow() async throws {
    try await withTempFile(lineCount: 5) { path in
        let tool = ReadFileTool()
        let result = try await tool.execute(arguments: [
            "path": ToolArgument(path),
            "offset": ToolArgument(Double(Int.min)),
        ])
        #expect(result.contains("1\tline 1"))
    }
}

@MainActor
@Test func readFileHandlesNegativeOffsetCountingFromEnd() async throws {
    try await withTempFile(lineCount: 5) { path in
        let tool = ReadFileTool()
        let result = try await tool.execute(arguments: [
            "path": ToolArgument(path),
            "offset": ToolArgument(-1),
        ])
        #expect(result == "5\tline 5")
    }
}

// MARK: - 渲染/审批阶段（工具执行之前）

/// 审批面板会在工具执行前调用 `displayDescription`；这里 trap 就是
/// 「App 在工具运行前直接退出」。
@MainActor
@Test func readFileDisplayDescriptionSurvivesIllegalArguments() {
    let tool = ReadFileTool()
    for value: Any in [1e100, Double.infinity, Double.nan, -1, 9_223_372_036_854_775_808.0] {
        let description = tool.displayDescription(for: [
            "path": ToolArgument("/tmp/a.txt"),
            "offset": ToolArgument(value),
            "limit": ToolArgument(value),
        ])
        #expect(!description.isEmpty)
    }
    #expect(tool.displayDescription(for: ["path": ToolArgument("/tmp/a.txt")]) == "读取 a.txt")
}

@MainActor
@Test func readFilePermissionRiskLevelSurvivesIllegalArguments() {
    let tool = ReadFileTool()
    let risk = tool.permissionRiskLevel(arguments: [
        "path": ToolArgument("/tmp/a.txt"),
        "offset": ToolArgument(1e100),
        "limit": ToolArgument(Double.nan),
    ])
    #expect(risk == .low)
}

@MainActor
@Test func shellDisplayDescriptionAndRiskSurviveIllegalArguments() {
    let tool = ShellTool()
    let arguments: [String: ToolArgument] = [
        "command": ToolArgument("echo hi"),
        "timeout": ToolArgument(1e100),
        "max_output_bytes": ToolArgument(Double.infinity),
        "unsandboxed": ToolArgument(true),
    ]
    #expect(!tool.displayDescription(for: arguments).isEmpty)
    #expect(tool.permissionRiskLevel(arguments: arguments) == .high)
    #expect(tool.requiresExplicitApproval(arguments: arguments))
}

// MARK: - run_command 数值参数

@Test func shellOutputBudgetFallsBackForUnrepresentableValues() {
    #expect(ShellTool.resolvedOutputBudget(for: [
        "max_output_bytes": ToolArgument(1e100),
    ]) == ShellOptions.defaultOptions.maxOutputBytes)
    #expect(ShellTool.resolvedOutputBudget(for: [
        "max_output_bytes": ToolArgument(Double.nan),
    ]) == ShellOptions.defaultOptions.maxOutputBytes)
    #expect(ShellTool.resolvedOutputBudget(for: [
        "max_output_bytes": ToolArgument(-1),
    ]) == ShellOptions.defaultOptions.maxOutputBytes)
}

@Test func shellOutputBudgetIsClampedToCeiling() {
    #expect(ShellTool.resolvedOutputBudget(for: [
        "max_output_bytes": ToolArgument(10_000_000_000),
    ]) == ShellTool.maxOutputBytesCeiling)
    #expect(ShellTool.resolvedOutputBudget(for: [
        "max_output_bytes": ToolArgument(40_000),
    ]) == 40_000)
}

@MainActor
@Test func shellRejectsUnrepresentableTimeoutAsArgumentError() async {
    let tool = ShellTool(workspaceRootProvider: { "/tmp" })
    do {
        _ = try await tool.execute(arguments: [
            "command": ToolArgument("echo hi"),
            "timeout": ToolArgument(1e100),
        ])
        Issue.record("Expected an argument error for an out-of-range timeout")
    } catch {
        #expect(String(describing: error).contains("timeout"))
    }
}

@MainActor
@Test func shellRejectsNegativeTimeoutAsArgumentError() async {
    let tool = ShellTool(workspaceRootProvider: { "/tmp" })
    do {
        _ = try await tool.execute(arguments: [
            "command": ToolArgument("echo hi"),
            "timeout": ToolArgument(-1),
        ])
        Issue.record("Expected an argument error for a negative timeout")
    } catch {
        #expect(String(describing: error).contains("timeout"))
    }
}

@MainActor
@Test func shellStillRunsWithAValidTimeout() async throws {
    let tool = ShellTool(workspaceRootProvider: { "/tmp" })
    let result = try await tool.execute(arguments: [
        "command": ToolArgument("echo hi"),
        "timeout": ToolArgument(30),
        "max_output_bytes": ToolArgument(40_000),
    ])
    #expect(result.contains("hi"))
}

// MARK: - 失败必须以抛出表达

/// 回归：这些失败分支曾经返回 "Error: ..." 字符串，默认 `executeResult`
/// 会把字符串包成 `isError == false` 的结果，调用方误以为成功。
@MainActor
@Test func globToolThrowsWhenPatternIsMissing() async {
    await #expect(throws: ToolExecutionError.self) {
        _ = try await GlobTool().executeResult(arguments: [:])
    }
}

@MainActor
@Test func listDirectoryToolThrowsWhenDirectoryDoesNotExist() async {
    let missing = FileManager.default.temporaryDirectory
        .appendingPathComponent("lumi-missing-\(UUID().uuidString)", isDirectory: true)
    await #expect(throws: ToolExecutionError.self) {
        _ = try await ListDirectoryTool().executeResult(arguments: [
            "path": ToolArgument(missing.path),
        ])
    }
}
