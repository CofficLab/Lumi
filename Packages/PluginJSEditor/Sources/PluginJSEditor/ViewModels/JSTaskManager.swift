import Foundation
import SuperLogKit
import os

@MainActor
public final class JSTaskManager: ObservableObject, SuperLog {
    public nonisolated static let emoji = "🟨"
    public nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.js-editor.tasks"
    )

    @Published private(set) var state: TaskState = .idle
    @Published private(set) var outputLines: [String] = []
    @Published private(set) var issues: [JSBuildIssue] = []
    @Published private(set) var testEvents: [JSTestEvent] = []
    @Published private(set) var lastDuration: TimeInterval = 0
    @Published private(set) var lastScriptName: String?

    private let runner = ScriptTaskRunner()
    private lazy var formatOnSaveCoordinator = FormatOnSaveCoordinator(runner: runner)

    public var errorCount: Int {
        issues.filter { $0.severity == .error }.count
    }

    public var warningCount: Int {
        issues.filter { $0.severity == .warning }.count
    }

    public func run(script: String, projectPath: String, arguments: [String] = [], mode: TaskState = .running) async {
        state = mode
        lastScriptName = script
        outputLines = []
        issues = []
        testEvents = []

        let result = await runner.runScript(script, projectPath: projectPath, arguments: arguments)
        apply(result: result)

        if mode == .testing {
            testEvents = TestOutputParser.parse(output: result.stdout + result.stderr)
            state = .idle
        } else {
            state = result.isSuccess ? .success : .failed
        }
    }

    public func build(projectPath: String, package: JSPackageInfo?) async {
        guard let script = package?.buildScripts.first ?? package?.scripts.keys.sorted().first(where: { $0 == "build" }) else {
            state = .failed
            outputLines = ["No build script found in package.json"]
            return
        }
        await run(script: script, projectPath: projectPath, mode: .building)
    }

    public func test(projectPath: String, package: JSPackageInfo?) async {
        guard let script = TestRunnerDetector.preferredScript(package: package) else {
            state = .failed
            outputLines = ["No test script found in package.json"]
            return
        }
        let args = TestRunnerDetector.defaultArguments(for: TestRunnerDetector.framework(package: package))
        await run(script: script, projectPath: projectPath, arguments: args, mode: .testing)
    }

    public func lint(fileURL: URL?, projectPath: String) async {
        state = .linting
        lastScriptName = "eslint"
        outputLines = []
        issues = []
        testEvents = []

        guard let result = await ESLintLSPBridge.lint(fileURL: fileURL, projectPath: projectPath, runner: runner) else {
            state = .failed
            outputLines = ["ESLint is not available for this project"]
            return
        }
        apply(result: result)
        state = result.isSuccess ? .success : .failed
    }

    public func format(fileURL: URL?, projectPath: String?) async {
        state = .formatting
        lastScriptName = "prettier"
        outputLines = []
        issues = []
        testEvents = []

        guard let result = await formatOnSaveCoordinator.formatIfPossible(fileURL: fileURL, projectPath: projectPath) else {
            state = .failed
            outputLines = ["Prettier is not available for this project"]
            return
        }
        apply(result: result)
        state = result.isSuccess ? .success : .failed
    }

    public func cancel() {
        Task { await runner.cancel() }
        state = .idle
    }

    private func apply(result: JSScriptResult) {
        lastDuration = result.duration
        outputLines = BuildOutputAdapter.outputLines(stdout: result.stdout, stderr: result.stderr)
        issues = BuildOutputAdapter.issues(stdout: result.stdout, stderr: result.stderr)
    }

    public enum TaskState: Equatable {
        case idle
        case running
        case building
        case testing
        case linting
        case formatting
        case success
        case failed
    }
}
