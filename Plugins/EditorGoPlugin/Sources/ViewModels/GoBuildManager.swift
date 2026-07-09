import Foundation
import SuperLogKit

import os

/// Go 构建管理器
///
/// 管理 go build 的执行状态、输出日志和解析后的构建问题。
@MainActor
public final class GoBuildManager: ObservableObject, SuperLog {
    public nonisolated static let emoji = "🔨"
    public nonisolated static let verbose: Bool = true
    public nonisolated static let logger = Logger(
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
    public var errorCount: Int {
        issues.filter { $0.severity == .error }.count
    }

    /// 警告数量
    public var warningCount: Int {
        issues.filter { $0.severity == .warning }.count
    }

    /// 上一次构建耗时
    @Published private(set) var lastBuildDuration: TimeInterval = 0

    /// 命令执行器
    private let runner = GoRunner()
    private var cancelRequested = false

    // MARK: - 执行构建

    /// 执行 go build
    public func build(workingDirectory: String) async {
        state = .building
        cancelRequested = false
        resetOutput()
        let startTime = Date()

        let result = await runner.execute(
            GoBuildCommand.allPackages,
            workingDirectory: workingDirectory
        )

        lastBuildDuration = Date().timeIntervalSince(startTime)
        applyBuildResult(result)

        if cancelRequested {
            state = .cancelled
        } else if result.isSuccess {
            state = .success
        } else {
            state = .failed
        }

        if GoBuildManager.verbose {
            GoBuildManager.logger.info("\(GoBuildManager.t)构建完成: \(result.exitCode), errors=\(self.errorCount), warnings=\(self.warningCount)")
        }
    }

    /// 执行 go fmt ./...
    public func format(workingDirectory: String) async {
        state = .formatting
        cancelRequested = false
        resetOutput()
        let startTime = Date()

        let result = await runner.execute(
            GoFmtCommand.allPackages,
            workingDirectory: workingDirectory
        )

        lastBuildDuration = Date().timeIntervalSince(startTime)
        applyBuildResult(result)
        state = cancelRequested ? .cancelled : (result.isSuccess ? .success : .failed)
    }

    /// 执行 go mod tidy
    public func tidyModule(workingDirectory: String) async {
        state = .tidying
        cancelRequested = false
        resetOutput()
        let startTime = Date()

        let result = await runner.execute(
            GoModCommand.tidy,
            workingDirectory: workingDirectory
        )

        lastBuildDuration = Date().timeIntervalSince(startTime)
        applyBuildResult(result)
        state = cancelRequested ? .cancelled : (result.isSuccess ? .success : .failed)
    }

    public func cancel() {
        guard state.isRunning else { return }
        cancelRequested = true
        Task { await runner.cancel() }
    }

    private func resetOutput() {
        outputLines = []
        issues = []
    }

    private func applyBuildResult(_ result: GoRunResult) {
        let parsed = GoBuildOutputParser.parse(stdout: result.stdout, stderr: result.stderr)
        outputLines = parsed.lines
        issues = parsed.issues
    }

    // MARK: - 状态

    enum BuildState: Equatable {
        case idle
        case building
        case formatting
        case tidying
        case cancelled
        case success
        case failed

        var isRunning: Bool {
            self == .building || self == .formatting || self == .tidying
        }
    }
}
