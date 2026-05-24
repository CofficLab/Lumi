import Foundation
import GoEditorCore
import os

@MainActor
final class GoTestManager: ObservableObject, SuperLog {
    nonisolated static let emoji = "🧪"
    nonisolated static let verbose: Bool = true
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.go-editor.test"
    )

    @Published private(set) var state: TestState = .idle
    @Published private(set) var outputLines: [String] = []
    @Published private(set) var testEvents: [GoTestOutputParser.TestEvent] = []
    @Published private(set) var issues: [GoBuildIssue] = []
    @Published private(set) var lastTestDuration: TimeInterval = 0

    var passedCount: Int {
        testEvents.filter { $0.status == .pass }.count
    }

    var failedCount: Int {
        testEvents.filter { $0.status == .fail }.count
    }

    var skippedCount: Int {
        testEvents.filter { $0.status == .skip }.count
    }

    private let runner = GoRunner()

    func test(workingDirectory: String) async {
        state = .testing
        outputLines = []
        testEvents = []
        issues = []
        let startTime = Date()

        let result = await runner.execute(
            GoTestCommand.allPackagesJSON,
            workingDirectory: workingDirectory
        )

        lastTestDuration = Date().timeIntervalSince(startTime)
        let output = result.stdout + "\n" + result.stderr
        testEvents = GoTestOutputParser.finalEvents(from: output)
        outputLines = GoBuildOutputParser.mergedLines(stdout: result.stdout, stderr: result.stderr)
        issues = result.stderr
            .components(separatedBy: .newlines)
            .compactMap(GoBuildIssue.parse)
        state = result.isSuccess ? .success : .failed

        if GoTestManager.verbose {
            GoTestManager.logger.info("\(GoTestManager.t)测试完成: passed=\(self.passedCount), failed=\(self.failedCount)")
        }
    }

    enum TestState: Equatable {
        case idle
        case testing
        case success
        case failed
    }
}
