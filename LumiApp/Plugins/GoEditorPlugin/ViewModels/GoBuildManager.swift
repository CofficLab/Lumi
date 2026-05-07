import Foundation
import MagicKit
import os

/// Go 构建管理器
///
/// 管理 go build 的执行状态、输出日志和解析后的构建问题。
@MainActor
final class GoBuildManager: ObservableObject, SuperLog {
    nonisolated static let emoji = "🔨"
    nonisolated static let verbose = false
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.go-editor.build"
    )

    // MARK: - 属性

    /// 构建状态
    @Published private(set) var state: BuildState = .idle

    /// 构建输出日志（原始行）
    @Published private(set) var outputLines: [String] = []

    /// 解析后的构建问题
    @Published private(set) var issues: [GoBuildIssue] = []

    /// 错误数量
    var errorCount: Int {
        issues.filter { $0.severity == .error }.count
    }

    /// 警告数量
    var warningCount: Int {
        issues.filter { $0.severity == .warning }.count
    }

    /// 上一次构建耗时
    @Published private(set) var lastBuildDuration: TimeInterval = 0

    /// 测试事件列表
    @Published private(set) var testEvents: [GoTestOutputParser.TestEvent] = []

    /// 命令执行器
    private let runner = GoRunner()

    // MARK: - 执行构建

    /// 执行 go build
    func build(workingDirectory: String) async {
        state = .building
        outputLines = []
        issues = []
        testEvents = []
        let startTime = Date()

        let result = await runner.execute(
            command: "build",
            arguments: ["-v", "./..."],
            workingDirectory: workingDirectory
        )

        lastBuildDuration = Date().timeIntervalSince(startTime)

        // 分割输出行
        let allOutput = (result.stderr + result.stdout)
            .components(separatedBy: "\n")
            .filter { !$0.isEmpty }
        outputLines = allOutput

        // 解析构建问题
        var parsed: [GoBuildIssue] = []
        for line in allOutput {
            if let issue = GoBuildIssue.parse(from: line) {
                parsed.append(issue)
            }
        }
        issues = parsed

        if result.isSuccess {
            state = .success
        } else {
            state = .failed
        }

        if GoBuildManager.verbose {
            GoBuildManager.logger.info("\(GoBuildManager.t)构建完成: \(result.exitCode), errors=\(parsed.filter { $0.severity == .error }.count), warnings=\(parsed.filter { $0.severity == .warning }.count)")
        }
    }

    /// 执行 go test
    func test(workingDirectory: String) async {
        state = .testing
        outputLines = []
        issues = []
        testEvents = []
        let startTime = Date()

        let result = await runner.execute(
            command: "test",
            arguments: ["-v", "-json", "./..."],
            workingDirectory: workingDirectory
        )

        lastBuildDuration = Date().timeIntervalSince(startTime)

        // 解析测试输出
        let parsed = GoTestOutputParser.parse(output: result.stdout + result.stderr)

        // 去重：只保留最终状态（pass/fail/skip），同一测试名保留最后出现的
        var deduped: [String: GoTestOutputParser.TestEvent] = [:]
        for event in parsed where event.status != .run {
            deduped[event.test] = event
        }
        testEvents = Array(deduped.values).sorted { $0.test.localizedCaseInsensitiveCompare($1.test) == .orderedAscending }

        // 原始输出行用于日志展示
        outputLines = (result.stderr + result.stdout)
            .components(separatedBy: "\n")
            .filter { !$0.isEmpty }

        // 从 test output 中提取构建错误
        let buildErrors = result.stderr
            .components(separatedBy: "\n")
            .compactMap { GoBuildIssue.parse(from: $0) }
        issues = buildErrors

        state = .idle

        if GoBuildManager.verbose {
            let events = testEvents
            GoBuildManager.logger.info("\(GoBuildManager.t)测试完成: passed=\(events.filter { $0.status == .pass }.count), failed=\(events.filter { $0.status == .fail }.count)")
        }
    }

    // MARK: - 状态

    enum BuildState: Equatable {
        case idle
        case building
        case testing
        case success
        case failed
    }
}
