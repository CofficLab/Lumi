import Foundation
import Testing
@testable import EditorBreadcrumbNavPlugin

@MainActor
struct BreadcrumbProjectAffinityTests {
    @MainActor
    @Test func fileInsideProjectRootIsAccepted() {
        let projectPath = "/tmp/GitOK"
        let fileURL = URL(fileURLWithPath: "/tmp/GitOK/Sources/App.swift")
        #expect(NavHeaderView.isFile(fileURL, inProjectPath: projectPath))
    }

    @MainActor
    @Test func fileFromAnotherProjectIsRejected() {
        let projectPath = "/tmp/GitOK"
        let fileURL = URL(fileURLWithPath: "/tmp/Lumi/LumiApp/Bootstrap/RootView.swift")
        #expect(!NavHeaderView.isFile(fileURL, inProjectPath: projectPath))
    }

    @MainActor
    @Test func emptyProjectPathIsRejected() {
        let fileURL = URL(fileURLWithPath: "/tmp/GitOK/Sources/App.swift")
        #expect(!NavHeaderView.isFile(fileURL, inProjectPath: ""))
    }
}
