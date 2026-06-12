import Foundation
import Testing
@testable import LumiPreviewKit

@Suite("SyntaxChecker")
struct SyntaxCheckerTests {
    @Test("returns valid when swiftc exits successfully")
    func returnsValidWhenCommandSucceeds() async {
        let runner = FakeCommandRunner(result: .init(exitCode: 0))
        let checker = LumiPreviewFacade.SyntaxChecker(swiftcPath: "/fake/swiftc", runner: runner)

        let result = await checker.check(fileURL: URL(fileURLWithPath: "/tmp/View.swift"))

        #expect(result == .valid)
        #expect(await runner.commands == [["/fake/swiftc", "-parse", "/tmp/View.swift"]])
    }

    @Test("includes extra arguments before file path")
    func includesExtraArgumentsBeforeFilePath() async {
        let runner = FakeCommandRunner(result: .init(exitCode: 0))
        let checker = LumiPreviewFacade.SyntaxChecker(swiftcPath: "/fake/swiftc", runner: runner)

        _ = await checker.check(
            fileURL: URL(fileURLWithPath: "/tmp/View.swift"),
            extraArguments: ["-sdk", "/tmp/SDK"]
        )

        #expect(await runner.commands == [["/fake/swiftc", "-parse", "-sdk", "/tmp/SDK", "/tmp/View.swift"]])
    }

    @Test("returns diagnostics when swiftc exits with failure")
    func returnsDiagnosticsWhenCommandFails() async throws {
        let runner = FakeCommandRunner(result: .init(
            exitCode: 1,
            standardError: "/tmp/View.swift:1:1: error: expected expression\n/tmp/View.swift:2:1: note: in expansion"
        ))
        let checker = LumiPreviewFacade.SyntaxChecker(runner: runner)

        let result = await checker.check(fileURL: URL(fileURLWithPath: "/tmp/View.swift"))
        guard case .invalid(let issues) = result else {
            Issue.record("Expected invalid syntax result.")
            return
        }

        #expect(issues.count == 2)
        #expect(issues[0].message.contains("expected expression"))
        #expect(issues[1].message.contains("note"))
    }

    @Test("returns thrown runner errors as invalid diagnostics")
    func returnsThrownRunnerErrorsAsInvalidDiagnostics() async {
        let runner = FakeCommandRunner(error: TestError.failed)
        let checker = LumiPreviewFacade.SyntaxChecker(runner: runner)

        let result = await checker.check(fileURL: URL(fileURLWithPath: "/tmp/View.swift"))
        guard case .invalid(let issues) = result else {
            Issue.record("Expected invalid syntax result.")
            return
        }

        #expect(issues.count == 1)
        #expect(!issues[0].message.isEmpty)
    }

    @Test("process runner captures large stdout and stderr without blocking")
    func processRunnerCapturesLargeOutputWithoutBlocking() async throws {
        let runner = LumiPreviewFacade.ProcessCommandRunner()
        let result = try await runner.run([
            "/bin/sh",
            "-c",
            """
            i=1
            while [ "$i" -le 300 ]; do
              printf 'stdout-%03d-%0512d\\n' "$i" 0
              printf 'stderr-%03d-%0512d\\n' "$i" 0 >&2
              i=$((i + 1))
            done
            """
        ])

        #expect(result.exitCode == 0)
        #expect(result.standardOutput.contains("stdout-300-"))
        #expect(result.standardError.contains("stderr-300-"))
        #expect(result.standardOutput.count > 150_000)
        #expect(result.standardError.count > 150_000)
    }
}

private enum TestError: Error {
    case failed
}

private actor FakeCommandRunner: LumiPreviewFacade.CommandRunning {
    private let result: LumiPreviewFacade.CommandResult?
    private let error: Error?
    private(set) var commands: [[String]] = []

    init(result: LumiPreviewFacade.CommandResult) {
        self.result = result
        self.error = nil
    }

    init(error: Error) {
        self.result = nil
        self.error = error
    }

    func run(_ command: [String]) async throws -> LumiPreviewFacade.CommandResult {
        commands.append(command)
        if let error {
            throw error
        }
        return try #require(result)
    }
}
