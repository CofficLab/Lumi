#if canImport(XCTest)
import XCTest
@testable import Lumi

@MainActor
final class XcodeSemanticAvailabilityTests: XCTestCase {
    func testInspectWorkspaceContextReturnsEmptyForNonXcodeProject() {
        let report = XcodeSemanticAvailability.inspectWorkspaceContext(
            input: .init(
                isXcodeProject: false,
                isInitialized: false,
                buildContextStatus: .unknown
            )
        )

        XCTAssertTrue(report.reasons.isEmpty)
    }

    func testInspectWorkspaceContextReportsInitializationAndUnavailableBuildContext() {
        let report = XcodeSemanticAvailability.inspectWorkspaceContext(
            input: .init(
                isXcodeProject: true,
                isInitialized: false,
                buildContextStatus: .unavailable("缺少 buildServer.json")
            )
        )

        XCTAssertEqual(report.reasons.map(\.id), ["server-not-started", "build-context-unavailable"])
        XCTAssertTrue(report.hasBlockingIssue)
    }

    func testInspectCurrentFileContextReportsFileNotInTarget() {
        let report = XcodeSemanticAvailability.inspectCurrentFileContext(
            input: .init(
                workspace: .init(
                    isXcodeProject: true,
                    isInitialized: true,
                    buildContextStatus: .available(.init(
                        buildServerJSONPath: "/tmp/buildServer.json",
                        workspacePath: "/tmp/Lumi.xcworkspace",
                        scheme: "Lumi"
                    ))
                ),
                fileName: "EditorPlugin.swift",
                activeScheme: "Lumi",
                activeDestinationName: "My Mac",
                matchedTargets: [],
                compatibleTargets: [],
                preferredTarget: nil
            )
        )

        XCTAssertEqual(report.reasons.map(\.id), ["file-not-in-target"])
        XCTAssertTrue(report.hasBlockingIssue)
    }

    func testInspectCurrentFileContextReportsSchemeMismatchAndDestinationUnknown() {
        let report = XcodeSemanticAvailability.inspectCurrentFileContext(
            input: .init(
                workspace: .init(
                    isXcodeProject: true,
                    isInitialized: true,
                    buildContextStatus: .available(.init(
                        buildServerJSONPath: "/tmp/buildServer.json",
                        workspacePath: "/tmp/Lumi.xcworkspace",
                        scheme: "Lumi"
                    ))
                ),
                fileName: "EditorPlugin.swift",
                activeScheme: "WidgetExtension",
                activeDestinationName: nil,
                matchedTargets: ["Lumi"],
                compatibleTargets: [],
                preferredTarget: nil
            )
        )

        XCTAssertEqual(report.reasons.map(\.id), ["scheme-excludes-targets", "destination-unknown"])
    }

    func testInspectCurrentFileContextReportsResolvedMultiTargetAsInfo() {
        let report = XcodeSemanticAvailability.inspectCurrentFileContext(
            input: .init(
                workspace: .init(
                    isXcodeProject: true,
                    isInitialized: true,
                    buildContextStatus: .needsResync
                ),
                fileName: "SharedView.swift",
                activeScheme: "Lumi",
                activeDestinationName: "My Mac",
                matchedTargets: ["Lumi", "LumiTests"],
                compatibleTargets: ["Lumi"],
                preferredTarget: "Lumi"
            )
        )

        XCTAssertEqual(report.reasons.map(\.id), ["build-context-resync", "multiple-targets-resolved"])
        XCTAssertTrue(report.hasWarnings)
    }

    func testInspectCurrentFileContextReportsAmbiguousMultiTarget() {
        let report = XcodeSemanticAvailability.inspectCurrentFileContext(
            input: .init(
                workspace: .init(
                    isXcodeProject: true,
                    isInitialized: true,
                    buildContextStatus: .available(.init(
                        buildServerJSONPath: "/tmp/buildServer.json",
                        workspacePath: "/tmp/Lumi.xcworkspace",
                        scheme: "Lumi"
                    ))
                ),
                fileName: "SharedView.swift",
                activeScheme: "Lumi",
                activeDestinationName: "My Mac",
                matchedTargets: ["Lumi", "LumiTests"],
                compatibleTargets: ["Lumi", "LumiTests"],
                preferredTarget: nil
            )
        )

        XCTAssertEqual(report.reasons.map(\.id), ["multiple-targets-ambiguous"])
        XCTAssertEqual(report.reasons.first?.severity, .warning)
    }

    func testWorkspacePreflightErrorTreatsNeedsResyncAsSoftNilButHardBlocking() {
        let report = XcodeSemanticAvailability.inspectWorkspaceContext(
            input: .init(
                isXcodeProject: true,
                isInitialized: true,
                buildContextStatus: .needsResync
            )
        )

        XCTAssertNil(XcodeSemanticAvailability.workspacePreflightError(report: report, strength: .soft))

        let hardError = XcodeSemanticAvailability.workspacePreflightError(report: report, strength: .hard)
        XCTAssertEqual(hardError, .buildContextUnavailable("当前 build context 已失效，工作区语义结果可能不准确。"))
    }

    func testFilePreflightErrorTreatsAmbiguousTargetAsSoftNil() {
        let input = XcodeSemanticAvailability.FileInspectionInput(
            workspace: .init(
                isXcodeProject: true,
                isInitialized: true,
                buildContextStatus: .available(.init(
                    buildServerJSONPath: "/tmp/buildServer.json",
                    workspacePath: "/tmp/Lumi.xcworkspace",
                    scheme: "Lumi"
                ))
            ),
            fileName: "SharedView.swift",
            activeScheme: "Lumi",
            activeDestinationName: "My Mac",
            matchedTargets: ["Lumi", "LumiTests"],
            compatibleTargets: ["Lumi", "LumiTests"],
            preferredTarget: nil
        )

        XCTAssertNil(XcodeSemanticAvailability.preflightError(input: input, strength: .soft))
        XCTAssertEqual(
            XcodeSemanticAvailability.preflightError(input: input, strength: .hard),
            .fileInMultipleTargets(file: "SharedView.swift", targets: ["Lumi", "LumiTests"], activeScheme: "Lumi")
        )
    }

    func testFilePreflightErrorBlocksSchemeMismatchForSoftAndHard() {
        let input = XcodeSemanticAvailability.FileInspectionInput(
            workspace: .init(
                isXcodeProject: true,
                isInitialized: true,
                buildContextStatus: .available(.init(
                    buildServerJSONPath: "/tmp/buildServer.json",
                    workspacePath: "/tmp/Lumi.xcworkspace",
                    scheme: "Lumi"
                ))
            ),
            fileName: "EditorPlugin.swift",
            activeScheme: "WidgetExtension",
            activeDestinationName: "My Mac",
            matchedTargets: ["Lumi"],
            compatibleTargets: [],
            preferredTarget: nil
        )

        let expected = XcodeLSPError.fileTargetsExcludedByActiveScheme(
            file: "EditorPlugin.swift",
            targets: ["Lumi"],
            activeScheme: "WidgetExtension"
        )
        XCTAssertEqual(XcodeSemanticAvailability.preflightError(input: input, strength: .soft), expected)
        XCTAssertEqual(XcodeSemanticAvailability.preflightError(input: input, strength: .hard), expected)
    }
}
#endif
