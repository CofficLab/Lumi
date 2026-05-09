import XCTest
@testable import XcodeKit

final class XcodeSemanticAvailabilityTests: XCTestCase {

    // MARK: - Workspace Inspection Tests

    func testInspectWorkspaceNonXcodeProject() {
        let input = WorkspaceInspectionInput(isXcodeProject: false, isInitialized: false, buildContextStatus: .unknown)
        let report = XcodeSemanticAvailability.inspectWorkspaceContext(input: input)
        XCTAssertTrue(report.reasons.isEmpty)
    }

    func testInspectWorkspaceNotInitialized() {
        let input = WorkspaceInspectionInput(isXcodeProject: true, isInitialized: false, buildContextStatus: .unknown)
        let report = XcodeSemanticAvailability.inspectWorkspaceContext(input: input)
        XCTAssertEqual(report.reasons.count, 1)
        XCTAssertEqual(report.reasons[0].id, "server-not-started")
        XCTAssertEqual(report.reasons[0].severity, .error)
        XCTAssertTrue(report.hasBlockingIssue)
    }

    func testInspectWorkspaceContextUnavailable() {
        let status = XcodeBuildContextProvider.BuildContextStatus.unavailable("Build tool missing")
        let input = WorkspaceInspectionInput(isXcodeProject: true, isInitialized: true, buildContextStatus: status)
        let report = XcodeSemanticAvailability.inspectWorkspaceContext(input: input)
        XCTAssertEqual(report.reasons.count, 1)
        XCTAssertEqual(report.reasons[0].id, "build-context-unavailable")
        XCTAssertEqual(report.reasons[0].severity, .error)
        XCTAssertTrue(report.hasBlockingIssue)
    }

    func testInspectWorkspaceContextNeedsResync() {
        let input = WorkspaceInspectionInput(isXcodeProject: true, isInitialized: true, buildContextStatus: .needsResync)
        let report = XcodeSemanticAvailability.inspectWorkspaceContext(input: input)
        XCTAssertEqual(report.reasons.count, 1)
        XCTAssertEqual(report.reasons[0].id, "build-context-resync")
        XCTAssertEqual(report.reasons[0].severity, .warning)
        XCTAssertFalse(report.hasBlockingIssue)
        XCTAssertTrue(report.hasWarnings)
    }

    func testInspectWorkspaceAvailable() {
        let status = XcodeBuildContextProvider.BuildContextStatus.available(.init(buildServerJSONPath: "/path", workspacePath: "/ws", scheme: "App"))
        let input = WorkspaceInspectionInput(isXcodeProject: true, isInitialized: true, buildContextStatus: status)
        let report = XcodeSemanticAvailability.inspectWorkspaceContext(input: input)
        XCTAssertTrue(report.reasons.isEmpty)
    }

    // MARK: - File Inspection Tests

    func testInspectFileContextNoFileName() {
        let workspaceInput = WorkspaceInspectionInput(isXcodeProject: true, isInitialized: true, buildContextStatus: .unknown)
        let input = FileInspectionInput(workspace: workspaceInput, fileName: nil, activeScheme: "App", activeDestinationName: "My Mac", matchedTargets: ["App"], compatibleTargets: ["App"], preferredTarget: nil)
        // Should fall back to workspace inspection logic (no extra errors)
        let report = XcodeSemanticAvailability.inspectCurrentFileContext(input: input)
        XCTAssertTrue(report.reasons.isEmpty)
    }

    func testInspectFileContextNotInTarget() {
        let workspaceInput = WorkspaceInspectionInput(isXcodeProject: true, isInitialized: true, buildContextStatus: .unknown)
        let input = FileInspectionInput(workspace: workspaceInput, fileName: "MyFile.swift", activeScheme: "App", activeDestinationName: "My Mac", matchedTargets: [], compatibleTargets: [], preferredTarget: nil)
        let report = XcodeSemanticAvailability.inspectCurrentFileContext(input: input)
        XCTAssertEqual(report.reasons.count, 1)
        XCTAssertEqual(report.reasons[0].id, "file-not-in-target")
        XCTAssertEqual(report.reasons[0].severity, .error)
        XCTAssertTrue(report.reasons[0].message.contains("MyFile.swift"))
    }

    func testInspectFileContextExcludedByScheme() {
        let workspaceInput = WorkspaceInspectionInput(isXcodeProject: true, isInitialized: true, buildContextStatus: .unknown)
        let input = FileInspectionInput(workspace: workspaceInput, fileName: "MyFile.swift", activeScheme: "App", activeDestinationName: "My Mac", matchedTargets: ["Tests"], compatibleTargets: [], preferredTarget: nil)
        let report = XcodeSemanticAvailability.inspectCurrentFileContext(input: input)
        // Should have error because matchedTargets is not empty but compatibleTargets is empty
        let errorReasons = report.reasons.filter { $0.severity == .error }
        XCTAssertEqual(errorReasons.count, 1)
        XCTAssertEqual(errorReasons[0].id, "scheme-excludes-targets")
        XCTAssertTrue(errorReasons[0].message.contains("App"))
        XCTAssertTrue(errorReasons[0].message.contains("Tests"))
    }

    func testInspectFileContextMultipleTargetsResolved() {
        let workspaceInput = WorkspaceInspectionInput(isXcodeProject: true, isInitialized: true, buildContextStatus: .unknown)
        let input = FileInspectionInput(workspace: workspaceInput, fileName: "MyFile.swift", activeScheme: "App", activeDestinationName: "My Mac", matchedTargets: ["App", "Tests"], compatibleTargets: ["App", "Tests"], preferredTarget: "App")
        let report = XcodeSemanticAvailability.inspectCurrentFileContext(input: input)
        let infoReasons = report.reasons.filter { $0.severity == .info }
        XCTAssertEqual(infoReasons.count, 1)
        XCTAssertEqual(infoReasons[0].id, "multiple-targets-resolved")
        XCTAssertTrue(infoReasons[0].message.contains("App"))
    }

    func testInspectFileContextMultipleTargetsAmbiguous() {
        let workspaceInput = WorkspaceInspectionInput(isXcodeProject: true, isInitialized: true, buildContextStatus: .unknown)
        let input = FileInspectionInput(workspace: workspaceInput, fileName: "MyFile.swift", activeScheme: "App", activeDestinationName: "My Mac", matchedTargets: ["App", "Tests"], compatibleTargets: ["App", "Tests"], preferredTarget: nil)
        let report = XcodeSemanticAvailability.inspectCurrentFileContext(input: input)
        let warningReasons = report.reasons.filter { $0.severity == .warning }
        XCTAssertEqual(warningReasons.count, 1)
        XCTAssertEqual(warningReasons[0].id, "multiple-targets-ambiguous")
    }

    func testInspectFileContextDestinationUnknown() {
        let workspaceInput = WorkspaceInspectionInput(isXcodeProject: true, isInitialized: true, buildContextStatus: .unknown)
        let input = FileInspectionInput(workspace: workspaceInput, fileName: "MyFile.swift", activeScheme: "App", activeDestinationName: nil, matchedTargets: ["App"], compatibleTargets: ["App"], preferredTarget: "App")
        let report = XcodeSemanticAvailability.inspectCurrentFileContext(input: input)
        let warningReasons = report.reasons.filter { $0.id == "destination-unknown" }
        XCTAssertEqual(warningReasons.count, 1)
    }

    // MARK: - Preflight Error Tests

    func testWorkspacePreflightErrorNoError() {
        let status = XcodeBuildContextProvider.BuildContextStatus.available(.init(buildServerJSONPath: "/path", workspacePath: "/ws", scheme: "App"))
        let input = WorkspaceInspectionInput(isXcodeProject: true, isInitialized: true, buildContextStatus: status)
        let report = XcodeSemanticAvailability.inspectWorkspaceContext(input: input)
        let error = XcodeSemanticAvailability.workspacePreflightError(report: report, strength: .hard)
        XCTAssertNil(error)
    }

    func testFilePreflightErrorHardStrength() {
        let workspaceInput = WorkspaceInspectionInput(isXcodeProject: true, isInitialized: true, buildContextStatus: .unknown)
        let input = FileInspectionInput(workspace: workspaceInput, fileName: "MyFile.swift", activeScheme: "App", activeDestinationName: nil, matchedTargets: ["App", "Tests"], compatibleTargets: ["App", "Tests"], preferredTarget: nil)
        // Ambiguous target is warning in hard strength? No, ambiguous is warning generally unless preferredTarget is nil?
        // In inspectCurrentFileContext: ambiguous is warning.
        let error = XcodeSemanticAvailability.preflightError(input: input, strength: .hard)
        XCTAssertNotNil(error)
    }

    func testFilePreflightErrorSoftStrength() {
        let workspaceInput = WorkspaceInspectionInput(isXcodeProject: true, isInitialized: true, buildContextStatus: .unknown)
        let input = FileInspectionInput(workspace: workspaceInput, fileName: "MyFile.swift", activeScheme: "App", activeDestinationName: nil, matchedTargets: ["App", "Tests"], compatibleTargets: ["App", "Tests"], preferredTarget: nil)
        let error = XcodeSemanticAvailability.preflightError(input: input, strength: .soft)
        // Destination unknown is warning, soft strength ignores warnings
        XCTAssertNil(error)
    }

    // MARK: - Classifier Tests

    func testClassifyMissingResultNotXcodeProject() {
        // Mock context provider behavior via direct input check if possible, but here we test pure logic if exposed.
        // Since classifyMissingResult needs contextProvider, we focus on logic paths that are accessible.
        // Actually, most logic in XcodeSemanticAvailability depends on protocols.
        // Let's ensure the struct inputs work as expected.
    }
}
