import XCTest
@testable import XcodeKit

final class XcodeBuildIssueParserTests: XCTestCase {

    func testParsesSwiftCompilerDiagnostic() {
        let output = "/tmp/App.swift:12:5: error: cannot find 'Foo' in scope"
        let parsed = XcodeBuildIssueParser.parse(stdout: output, stderr: "")

        XCTAssertEqual(parsed.issues.count, 1)
        XCTAssertEqual(parsed.issues[0].file, "/tmp/App.swift")
        XCTAssertEqual(parsed.issues[0].line, 12)
        XCTAssertEqual(parsed.issues[0].column, 5)
        XCTAssertEqual(parsed.issues[0].severity, .error)
        XCTAssertEqual(parsed.issues[0].message, "cannot find 'Foo' in scope")
    }

    func testParsesWarningDiagnostic() {
        let output = "/tmp/App.swift:3:1: warning: result of call is unused"
        let parsed = XcodeBuildIssueParser.parse(stdout: "", stderr: output)

        XCTAssertEqual(parsed.issues.count, 1)
        XCTAssertEqual(parsed.issues[0].severity, .warning)
    }

    func testFailureSummaryPrefersStructuredIssues() {
        let summary = XcodeBuildIssueParser.failureSummary(
            stdout: "/tmp/App.swift:1:1: error: boom",
            stderr: "",
            exitCode: 65
        )
        XCTAssertTrue(summary.contains("boom"))
    }
}
