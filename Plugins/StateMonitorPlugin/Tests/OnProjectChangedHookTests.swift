import Foundation
import Testing
@testable import StateMonitorPlugin

@Suite("OnProjectChangedHook project consistency")
@MainActor
struct OnProjectChangedHookTests {
    @Test("Keeps a conversation that belongs to the new project")
    func keepsMatchingProject() {
        #expect(
            OnProjectChangedHook.shouldDeselect(
                conversationProjectPath: "/tmp/project-b",
                newProjectPath: "/tmp/project-b"
            ) == false
        )
    }

    @Test("Normalizes paths before comparing")
    func normalizesPaths() {
        #expect(
            OnProjectChangedHook.shouldDeselect(
                conversationProjectPath: "/tmp/project-b/../project-b",
                newProjectPath: "/tmp/project-b"
            ) == false
        )
    }

    @Test("Clears a conversation that belongs to another project")
    func clearsMismatchedProject() {
        #expect(
            OnProjectChangedHook.shouldDeselect(
                conversationProjectPath: "/tmp/project-a",
                newProjectPath: "/tmp/project-b"
            )
        )
    }

    @Test("Handles project open and close transitions")
    func handlesNilProjects() {
        #expect(
            OnProjectChangedHook.shouldDeselect(
                conversationProjectPath: nil,
                newProjectPath: "/tmp/project-b"
            )
        )
        #expect(
            OnProjectChangedHook.shouldDeselect(
                conversationProjectPath: "/tmp/project-a",
                newProjectPath: nil
            )
        )
        #expect(
            OnProjectChangedHook.shouldDeselect(
                conversationProjectPath: nil,
                newProjectPath: nil
            ) == false
        )
    }
}
