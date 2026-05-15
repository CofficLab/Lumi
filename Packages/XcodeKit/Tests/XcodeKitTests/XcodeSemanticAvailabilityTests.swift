import XCTest
@testable import XcodeKit

@MainActor
final class XcodeSemanticAvailabilityTests: XCTestCase {

    // MARK: - Workspace Inspection Tests

    func testInspectWorkspaceNonXcodeProject() {
        let input = XcodeSemanticAvailability.WorkspaceInspectionInput(isXcodeProject: false, isInitialized: false, buildContextStatus: .unknown)
        let report = XcodeSemanticAvailability.inspectWorkspaceContext(input: input)
        XCTAssertTrue(report.reasons.isEmpty)
    }

    func testInspectWorkspaceNotInitialized() {
        let input = XcodeSemanticAvailability.WorkspaceInspectionInput(isXcodeProject: true, isInitialized: false, buildContextStatus: .unknown)
        let report = XcodeSemanticAvailability.inspectWorkspaceContext(input: input)
        XCTAssertEqual(report.reasons.count, 1)
        XCTAssertEqual(report.reasons[0].id, "server-not-started")
        XCTAssertEqual(report.reasons[0].severity, XcodeSemanticAvailability.ReasonSeverity.error)
        XCTAssertTrue(report.hasBlockingIssue)
    }

    func testInspectWorkspaceContextUnavailable() {
        let status = XcodeBuildContextProvider.BuildContextStatus.unavailable("Build tool missing")
        let input = XcodeSemanticAvailability.WorkspaceInspectionInput(isXcodeProject: true, isInitialized: true, buildContextStatus: status)
        let report = XcodeSemanticAvailability.inspectWorkspaceContext(input: input)
        XCTAssertEqual(report.reasons.count, 1)
        XCTAssertEqual(report.reasons[0].id, "build-context-unavailable")
        XCTAssertEqual(report.reasons[0].severity, XcodeSemanticAvailability.ReasonSeverity.error)
        XCTAssertTrue(report.hasBlockingIssue)
    }

    func testInspectWorkspaceContextNeedsResync() {
        let input = XcodeSemanticAvailability.WorkspaceInspectionInput(isXcodeProject: true, isInitialized: true, buildContextStatus: .needsResync)
        let report = XcodeSemanticAvailability.inspectWorkspaceContext(input: input)
        XCTAssertEqual(report.reasons.count, 1)
        XCTAssertEqual(report.reasons[0].id, "build-context-resync")
        XCTAssertEqual(report.reasons[0].severity, XcodeSemanticAvailability.ReasonSeverity.warning)
        XCTAssertFalse(report.hasBlockingIssue)
        XCTAssertTrue(report.hasWarnings)
    }

    func testInspectWorkspaceAvailable() {
        let status = XcodeBuildContextProvider.BuildContextStatus.available(.init(buildServerJSONPath: "/path", workspacePath: "/ws", scheme: "App"))
        let input = XcodeSemanticAvailability.WorkspaceInspectionInput(isXcodeProject: true, isInitialized: true, buildContextStatus: status)
        let report = XcodeSemanticAvailability.inspectWorkspaceContext(input: input)
        XCTAssertTrue(report.reasons.isEmpty)
    }

    // MARK: - File Inspection Tests

    func testInspectFileContextNoFileName() {
        let workspaceInput = XcodeSemanticAvailability.WorkspaceInspectionInput(isXcodeProject: true, isInitialized: true, buildContextStatus: .unknown)
        let input = XcodeSemanticAvailability.FileInspectionInput(workspace: workspaceInput, fileName: nil, activeScheme: "App", activeDestinationName: "My Mac", matchedTargets: ["App"], compatibleTargets: ["App"], preferredTarget: nil)
        // Should fall back to workspace inspection logic (no extra errors)
        let report = XcodeSemanticAvailability.inspectCurrentFileContext(input: input)
        XCTAssertTrue(report.reasons.isEmpty)
    }

    func testInspectFileContextNotInTarget() {
        let workspaceInput = XcodeSemanticAvailability.WorkspaceInspectionInput(isXcodeProject: true, isInitialized: true, buildContextStatus: .unknown)
        let input = XcodeSemanticAvailability.FileInspectionInput(workspace: workspaceInput, fileName: "MyFile.swift", activeScheme: "App", activeDestinationName: "My Mac", matchedTargets: [], compatibleTargets: [], preferredTarget: nil)
        let report = XcodeSemanticAvailability.inspectCurrentFileContext(input: input)
        XCTAssertEqual(report.reasons.count, 1)
        XCTAssertEqual(report.reasons[0].id, "file-not-in-target")
        XCTAssertEqual(report.reasons[0].severity, XcodeSemanticAvailability.ReasonSeverity.error)
        XCTAssertTrue(report.reasons[0].message.contains("MyFile.swift"))
    }

    func testInspectFileContextExcludedByScheme() {
        let workspaceInput = XcodeSemanticAvailability.WorkspaceInspectionInput(isXcodeProject: true, isInitialized: true, buildContextStatus: .unknown)
        let input = XcodeSemanticAvailability.FileInspectionInput(workspace: workspaceInput, fileName: "MyFile.swift", activeScheme: "App", activeDestinationName: "My Mac", matchedTargets: ["Tests"], compatibleTargets: [], preferredTarget: nil)
        let report = XcodeSemanticAvailability.inspectCurrentFileContext(input: input)
        // Should have error because matchedTargets is not empty but compatibleTargets is empty
        let errorReasons = report.reasons.filter { $0.severity == XcodeSemanticAvailability.ReasonSeverity.error }
        XCTAssertEqual(errorReasons.count, 1)
        XCTAssertEqual(errorReasons[0].id, "scheme-excludes-targets")
        XCTAssertTrue(errorReasons[0].message.contains("App"))
        XCTAssertTrue(errorReasons[0].message.contains("Tests"))
    }

    func testInspectFileContextMultipleTargetsResolved() {
        let workspaceInput = XcodeSemanticAvailability.WorkspaceInspectionInput(isXcodeProject: true, isInitialized: true, buildContextStatus: .unknown)
        let input = XcodeSemanticAvailability.FileInspectionInput(workspace: workspaceInput, fileName: "MyFile.swift", activeScheme: "App", activeDestinationName: "My Mac", matchedTargets: ["App", "Tests"], compatibleTargets: ["App", "Tests"], preferredTarget: "App")
        let report = XcodeSemanticAvailability.inspectCurrentFileContext(input: input)
        let infoReasons = report.reasons.filter { $0.severity == XcodeSemanticAvailability.ReasonSeverity.info }
        XCTAssertEqual(infoReasons.count, 1)
        XCTAssertEqual(infoReasons[0].id, "multiple-targets-resolved")
        XCTAssertTrue(infoReasons[0].message.contains("App"))
    }

    func testInspectFileContextMultipleTargetsAmbiguous() {
        let workspaceInput = XcodeSemanticAvailability.WorkspaceInspectionInput(isXcodeProject: true, isInitialized: true, buildContextStatus: .unknown)
        let input = XcodeSemanticAvailability.FileInspectionInput(workspace: workspaceInput, fileName: "MyFile.swift", activeScheme: "App", activeDestinationName: "My Mac", matchedTargets: ["App", "Tests"], compatibleTargets: ["App", "Tests"], preferredTarget: nil)
        let report = XcodeSemanticAvailability.inspectCurrentFileContext(input: input)
        let warningReasons = report.reasons.filter { $0.severity == XcodeSemanticAvailability.ReasonSeverity.warning }
        XCTAssertEqual(warningReasons.count, 1)
        XCTAssertEqual(warningReasons[0].id, "multiple-targets-ambiguous")
    }

    func testInspectFileContextDestinationUnknown() {
        let workspaceInput = XcodeSemanticAvailability.WorkspaceInspectionInput(isXcodeProject: true, isInitialized: true, buildContextStatus: .unknown)
        let input = XcodeSemanticAvailability.FileInspectionInput(workspace: workspaceInput, fileName: "MyFile.swift", activeScheme: "App", activeDestinationName: nil, matchedTargets: ["App"], compatibleTargets: ["App"], preferredTarget: "App")
        let report = XcodeSemanticAvailability.inspectCurrentFileContext(input: input)
        let warningReasons = report.reasons.filter { $0.id == "destination-unknown" }
        XCTAssertEqual(warningReasons.count, 1)
    }

    func testInspectFileContextFromSnapshotUsesSnapshotTargets() {
        let snapshot = XcodeEditorContextSnapshot(
            projectPath: "/Project",
            workspaceName: "Project",
            workspacePath: "/Project/Project.xcodeproj",
            activeScheme: "App",
            activeSchemeBuildableTargets: ["App"],
            activeConfiguration: "Debug",
            activeDestination: "My Mac",
            buildContextStatus: "Available",
            isXcodeProject: true,
            schemes: ["App"],
            configurations: ["Debug"],
            currentFilePath: "/Project/Sources/MyFile.swift",
            currentFileTarget: "App",
            currentFileMatchedTargets: ["App", "Tests"],
            currentFileIsInTarget: true
        )
        let cachedState = BridgeCachedState(
            workspaceFolders: nil,
            buildServerPath: nil,
            activeScheme: "App",
            activeConfiguration: "Debug",
            activeDestination: "My Mac",
            buildContextStatus: "Available",
            isXcodeProject: true,
            isInitialized: true,
            workspaceName: "Project",
            workspacePath: "/Project/Project.xcodeproj",
            schemes: ["App"],
            configurations: ["Debug"],
            projectPath: "/Project"
        )

        let report = XcodeSemanticAvailability.inspectCurrentFileContext(
            snapshot: snapshot,
            cachedState: cachedState,
            buildContextStatus: .available(.init(buildServerJSONPath: "/buildServer.json", workspacePath: "/Project/Project.xcodeproj", scheme: "App"))
        )

        XCTAssertTrue(report.reasons.contains { $0.id == "multiple-targets-resolved" })
        XCTAssertFalse(report.reasons.contains { $0.id == "scheme-excludes-targets" })
    }

    // MARK: - Preflight Error Tests

    func testWorkspacePreflightErrorNoError() {
        let status = XcodeBuildContextProvider.BuildContextStatus.available(.init(buildServerJSONPath: "/path", workspacePath: "/ws", scheme: "App"))
        let input = XcodeSemanticAvailability.WorkspaceInspectionInput(isXcodeProject: true, isInitialized: true, buildContextStatus: status)
        let report = XcodeSemanticAvailability.inspectWorkspaceContext(input: input)
        let error = XcodeSemanticAvailability.workspacePreflightError(report: report, strength: .hard)
        XCTAssertNil(error)
    }

    func testFilePreflightErrorHardStrength() {
        let workspaceInput = XcodeSemanticAvailability.WorkspaceInspectionInput(isXcodeProject: true, isInitialized: true, buildContextStatus: .unknown)
        let input = XcodeSemanticAvailability.FileInspectionInput(workspace: workspaceInput, fileName: "MyFile.swift", activeScheme: "App", activeDestinationName: nil, matchedTargets: ["App", "Tests"], compatibleTargets: ["App", "Tests"], preferredTarget: nil)
        let error = XcodeSemanticAvailability.preflightError(input: input, strength: .hard)
        XCTAssertNotNil(error)
    }

    func testFilePreflightErrorSoftStrength() {
        let workspaceInput = XcodeSemanticAvailability.WorkspaceInspectionInput(isXcodeProject: true, isInitialized: true, buildContextStatus: .unknown)
        let input = XcodeSemanticAvailability.FileInspectionInput(workspace: workspaceInput, fileName: "MyFile.swift", activeScheme: "App", activeDestinationName: nil, matchedTargets: ["App", "Tests"], compatibleTargets: ["App", "Tests"], preferredTarget: nil)
        let error = XcodeSemanticAvailability.preflightError(input: input, strength: .soft)
        // Destination unknown is warning, soft strength ignores warnings
        XCTAssertNil(error)
    }

    // MARK: - Report Tests

    func testReportHasBlockingIssueFalse() {
        let report = XcodeSemanticAvailability.Report(reasons: [
            XcodeSemanticAvailability.Reason(id: "w1", severity: .warning, title: "Warning", message: "msg"),
            XcodeSemanticAvailability.Reason(id: "i1", severity: .info, title: "Info", message: "msg"),
        ])
        XCTAssertFalse(report.hasBlockingIssue)
        XCTAssertTrue(report.hasWarnings)
    }

    func testReportHasBlockingIssueTrue() {
        let report = XcodeSemanticAvailability.Report(reasons: [
            XcodeSemanticAvailability.Reason(id: "e1", severity: .error, title: "Error", message: "msg"),
            XcodeSemanticAvailability.Reason(id: "w1", severity: .warning, title: "Warning", message: "msg"),
        ])
        XCTAssertTrue(report.hasBlockingIssue)
        XCTAssertTrue(report.hasWarnings)
    }

    func testReportEmptyReasons() {
        let report = XcodeSemanticAvailability.Report(reasons: [])
        XCTAssertFalse(report.hasBlockingIssue)
        XCTAssertFalse(report.hasWarnings)
    }

    // MARK: - Reason Tests

    func testReasonEquality() {
        let r1 = XcodeSemanticAvailability.Reason(id: "test", severity: .error, title: "T", message: "M")
        let r2 = XcodeSemanticAvailability.Reason(id: "test", severity: .error, title: "T", message: "M")
        XCTAssertEqual(r1, r2)
    }

    func testReasonInequality() {
        let r1 = XcodeSemanticAvailability.Reason(id: "test1", severity: .error, title: "T", message: "M")
        let r2 = XcodeSemanticAvailability.Reason(id: "test2", severity: .error, title: "T", message: "M")
        XCTAssertNotEqual(r1, r2)
    }

    // MARK: - WorkspaceInspectionInput Tests

    func testWorkspaceInspectionInputEquality() {
        let lhs = XcodeSemanticAvailability.WorkspaceInspectionInput(isXcodeProject: true, isInitialized: true, buildContextStatus: .unknown)
        let rhs = XcodeSemanticAvailability.WorkspaceInspectionInput(isXcodeProject: true, isInitialized: true, buildContextStatus: .unknown)
        XCTAssertEqual(lhs, rhs)
    }

    // MARK: - FileInspectionInput Tests

    func testFileInspectionInputEquality() {
        let ws = XcodeSemanticAvailability.WorkspaceInspectionInput(isXcodeProject: true, isInitialized: true, buildContextStatus: .unknown)
        let lhs = XcodeSemanticAvailability.FileInspectionInput(workspace: ws, fileName: "A.swift", activeScheme: "App", activeDestinationName: "Mac", matchedTargets: ["App"], compatibleTargets: ["App"], preferredTarget: "App")
        let rhs = XcodeSemanticAvailability.FileInspectionInput(workspace: ws, fileName: "A.swift", activeScheme: "App", activeDestinationName: "Mac", matchedTargets: ["App"], compatibleTargets: ["App"], preferredTarget: "App")
        XCTAssertEqual(lhs, rhs)
    }
}
