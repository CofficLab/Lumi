import Foundation
import SuperLogKit

import os

@MainActor
public final class GoTestManager: ObservableObject, SuperLog {
    public nonisolated static let emoji = "🧪"
    public nonisolated static let verbose: Bool = true
    public nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.go-editor.test"
    )

    @Published private(set) var state: TestState = .idle
    @Published private(set) var outputLines: [String] = []
    @Published private(set) var testEvents: [GoTestOutputParser.TestEvent] = []
    @Published private(set) var issues: [GoBuildIssue] = []
    @Published private(set) var lastTestDuration: TimeInterval = 0

    public var passedCount: Int {
        testEvents.filter { $0.status == .pass }.count
    }

    public var failedCount: Int {
        testEvents.filter { $0.status == .fail }.count
    }

    public var skippedCount: Int {
        testEvents.filter { $0.status == .skip }.count
    }

    private let runner = GoRunner()
    private var cancelRequested = false

    public func test(workingDirectory: String) async {
        state = .testing
        cancelRequested = false
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
        state = cancelRequested ? .cancelled : (result.isSuccess ? .success : .failed)

        if GoTestManager.verbose {
            GoTestManager.logger.info("\(GoTestManager.t)测试完成: passed=\(self.passedCount), failed=\(self.failedCount)")
        }
    }

    public func cancel() {
        guard state == .testing else { return }
        cancelRequested = true
        Task { await runner.cancel() }
    }

    enum TestState: Equatable {
        case idle
        case testing
        case cancelled
        case success
        case failed
    }
}
