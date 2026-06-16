import EditorKernel
import Testing
@testable import EditorPanelPlugin

@Suite struct EditorPanelProjectContextWarningTests {
    @Test func skipsNotInTargetWarningWhileMembershipUnresolved() {
        let snapshot = EditorProjectContextSnapshot(
            projectPath: "/Project",
            workspaceName: "Project",
            workspacePath: "/Project/Project.xcodeproj",
            activeScheme: "App",
            activeSchemeBuildableTargets: [],
            activeConfiguration: "Debug",
            activeDestination: "My Mac",
            contextStatus: .available("Indexed"),
            isStructuredProject: true,
            schemes: ["App"],
            configurations: ["Debug"],
            currentFilePath: "/Project/AppBootstrap.swift",
            currentFilePrimaryTarget: nil,
            currentFileMatchedTargets: [],
            currentFileIsInTarget: false,
            isTargetMembershipResolved: false
        )

        #expect(
            EditorPanelService.projectContextWarningMessage(
                snapshot: snapshot,
                hasCurrentFile: true
            ) == nil
        )
    }

    @Test func showsNotInTargetWarningAfterMembershipResolved() {
        let snapshot = EditorProjectContextSnapshot(
            projectPath: "/Project",
            workspaceName: "Project",
            workspacePath: "/Project/Project.xcodeproj",
            activeScheme: "App",
            activeSchemeBuildableTargets: ["App"],
            activeConfiguration: "Debug",
            activeDestination: "My Mac",
            contextStatus: .available("Indexed"),
            isStructuredProject: true,
            schemes: ["App"],
            configurations: ["Debug"],
            currentFilePath: "/Project/AppBootstrap.swift",
            currentFilePrimaryTarget: nil,
            currentFileMatchedTargets: [],
            currentFileIsInTarget: false,
            isTargetMembershipResolved: true
        )

        let message = EditorPanelService.projectContextWarningMessage(
            snapshot: snapshot,
            hasCurrentFile: true
        )

        #expect(message != nil)
        #expect(message?.isEmpty == false)
    }

    @Test func skipsNotInTargetWarningWhileResolving() {
        let snapshot = EditorProjectContextSnapshot(
            projectPath: "/Project",
            workspaceName: "Project",
            workspacePath: "/Project/Project.xcodeproj",
            activeScheme: "App",
            activeSchemeBuildableTargets: [],
            activeConfiguration: "Debug",
            activeDestination: "My Mac",
            contextStatus: .resolving,
            isStructuredProject: true,
            schemes: ["App"],
            configurations: ["Debug"],
            currentFilePath: "/Project/AppBootstrap.swift",
            currentFilePrimaryTarget: nil,
            currentFileMatchedTargets: [],
            currentFileIsInTarget: false,
            isTargetMembershipResolved: false
        )

        #expect(
            EditorPanelService.projectContextWarningMessage(
                snapshot: snapshot,
                hasCurrentFile: true
            ) == nil
        )
    }
}
