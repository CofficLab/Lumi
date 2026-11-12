import Foundation
import KitAgentTool
import KitShell
import Testing
@testable import PluginToolManager

/// `run_command` 的非阻塞行为契约。
///
/// 核心约定：
/// - `timeout` 是**前台预算**而不是杀进程的死线：预算耗尽时命令继续在后台跑
/// - 结果文本必须含后台 ID、输出路径与 `read_file` 提示
/// - 以 `sleep` 开头的命令豁免自动后台（它们是故意等待）
/// - 失败路径仍抛 `ToolExecutionError`，不用字符串表达失败
@Suite("ShellTool Background Handoff")
struct ShellToolBackgroundTests {

    // MARK: - Schema

    @Test("schema 声明了 run_in_background 与新的 timeout 语义")
    func schemaAdvertisesBackgroundArguments() {
        let tool = ShellTool()
        let schema = tool.inputSchema(for: .english)
        let properties = schema["properties"] as? [String: Any]

        #expect(properties?["run_in_background"] != nil)
        let timeout = (properties?["timeout"] as? [String: Any])?["description"] as? String
        #expect(timeout?.contains("foreground budget") == true)
        #expect(timeout?.contains("600") == true)
    }

    @Test("description 说明长命令不会阻塞回合")
    func descriptionMentionsNonBlockingBehaviour() {
        let tool = ShellTool()
        let description = tool.description(for: .english)
        #expect(description.contains("background"))
        #expect(description.contains("read_file"))
    }

    // MARK: - sleep 豁免

    @Test("以 sleep 开头的命令被识别为故意等待")
    func sleepFirstCommandsAreDeliberateWaits() {
        #expect(ShellTool.isDeliberateWait("sleep 5"))
        #expect(ShellTool.isDeliberateWait("  sleep 5  "))
        #expect(ShellTool.isDeliberateWait("/bin/sleep 5"))
        #expect(ShellTool.isDeliberateWait("SLEEP 5"))
    }

    @Test("非 sleep 开头的命令不算故意等待")
    func otherCommandsAreNotDeliberateWaits() {
        #expect(!ShellTool.isDeliberateWait("swift build"))
        #expect(!ShellTool.isDeliberateWait("echo sleep"))
        #expect(!ShellTool.isDeliberateWait(""))
    }

    @Test("sleep 命令不自动转后台：仍然等它跑完")
    func sleepCommandWaitsInForeground() async throws {
        let tool = ShellTool(workspaceRootProvider: { "/tmp" })
        let result = try await tool.execute(arguments: [
            "command": ToolArgument("sleep 1"),
        ])
        // 前台等待完成：返回的是执行结果而不是后台交接提示。
        #expect(!result.contains("running in the background"))
    }

    // MARK: - 结果文本

    @Test("后台结果文本含任务 ID、输出路径与 read_file 提示")
    func backgroundResultTextContainsTaskIDPathAndHint() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let registry = BackgroundTaskRegistry(rootDirectory: directory)
        let tool = ShellTool(
            workspaceRootProvider: { "/tmp" },
            backgroundTaskRegistryProvider: { registry }
        )

        let result = try await tool.execute(arguments: [
            "command": ToolArgument("sleep 30"),
            "run_in_background": ToolArgument(true),
        ])

        #expect(result.contains("running in the background"))
        #expect(result.contains("Background task ID:"))
        #expect(result.contains("Output file:"))
        #expect(result.contains("read_file"))

        // 输出路径必须真的存在——模型会用 read_file 去读它。
        let pathLine = result
            .split(separator: "\n")
            .first { $0.hasPrefix("Output file:") }
        let path = pathLine.map { $0.replacingOccurrences(of: "Output file: ", with: "") } ?? ""
        #expect(path.hasSuffix(".log"))
        #expect(FileManager.default.fileExists(atPath: path))

        // 清理后台进程。
        let taskIDLine = result
            .split(separator: "\n")
            .first { $0.hasPrefix("Background task ID:") }
        let taskID = taskIDLine.map { $0.replacingOccurrences(of: "Background task ID: ", with: "") } ?? ""
        _ = await registry.stop(taskID: taskID)
    }

    @Test("显式后台模式立即返回，不等命令跑完")
    func explicitBackgroundReturnsImmediately() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let registry = BackgroundTaskRegistry(rootDirectory: directory)
        let tool = ShellTool(
            workspaceRootProvider: { "/tmp" },
            backgroundTaskRegistryProvider: { registry }
        )

        let startedAt = Date()
        let result = try await tool.execute(arguments: [
            "command": ToolArgument("sleep 30"),
            "run_in_background": ToolArgument(true),
        ])
        let elapsed = Date().timeIntervalSince(startedAt)

        #expect(elapsed < 5.0)
        #expect(result.contains("running in the background"))

        let taskIDLine = result
            .split(separator: "\n")
            .first { $0.hasPrefix("Background task ID:") }
        let taskID = taskIDLine.map { $0.replacingOccurrences(of: "Background task ID: ", with: "") } ?? ""
        _ = await registry.stop(taskID: taskID)
    }

    // MARK: - 预算交接

    @Test("预算耗尽时命令转入后台且进程继续运行")
    func budgetExpiryHandsOffToBackground() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let registry = BackgroundTaskRegistry(rootDirectory: directory)
        let tool = ShellTool(
            commandTimeout: 1,
            workspaceRootProvider: { "/tmp" },
            backgroundTaskRegistryProvider: { registry }
        )

        let startedAt = Date()
        // 注意：不能用 `sleep 30` —— 以 sleep 开头的命令是故意等待，豁免自动后台。
        let result = try await tool.execute(arguments: [
            "command": ToolArgument("while true; do sleep 1; done"),
        ])
        let elapsed = Date().timeIntervalSince(startedAt)

        #expect(result.contains("running in the background"))
        // 必须在预算内返回，而不是等 30 秒。
        #expect(elapsed < 10.0)

        let taskIDLine = result
            .split(separator: "\n")
            .first { $0.hasPrefix("Background task ID:") }
        let taskID = taskIDLine.map { $0.replacingOccurrences(of: "Background task ID: ", with: "") } ?? ""
        let record = await registry.task(for: taskID)
        #expect(record?.status == .running)

        _ = await registry.stop(taskID: taskID)
    }

    // MARK: - 失败路径

    @Test("没有登记表时后台化显式失败而不是谎称成功")
    func backgroundWithoutRegistryThrows() async {
        let tool = ShellTool(workspaceRootProvider: { "/tmp" })

        await #expect(throws: ToolExecutionError.self) {
            _ = try await tool.execute(arguments: [
                "command": ToolArgument("sleep 30"),
                "run_in_background": ToolArgument(true),
            ])
        }
    }

    @Test("超时上限被钳制到 600 秒")
    func timeoutIsClampedToCeiling() {
        #expect(ShellTool.maxForegroundBudgetSeconds == 600)
    }

    // MARK: - 短命令

    @Test("短命令行为不变：返回执行结果而不是后台提示")
    func shortCommandStillReturnsResult() async throws {
        let tool = ShellTool(workspaceRootProvider: { "/tmp" })
        let result = try await tool.execute(arguments: [
            "command": ToolArgument("echo hello"),
        ])
        #expect(result.contains("hello"))
        #expect(!result.contains("running in the background"))
    }
}

// MARK: - Helpers

private func makeTemporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("ShellToolBackgroundTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}
