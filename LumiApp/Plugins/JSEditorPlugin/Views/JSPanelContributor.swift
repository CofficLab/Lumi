import Foundation
import SwiftUI

@MainActor
final class JSPanelContributor: SuperEditorPanelContributor {
    let id = "js.panels"

    private let taskManager: JSTaskManager

    init(taskManager: JSTaskManager) {
        self.taskManager = taskManager
    }

    func providePanels(state: EditorState) -> [EditorPanelSuggestion] {
        guard isJSLanguage(state.detectedLanguage?.tsName) else { return [] }
        guard shouldShowOutput || shouldShowTests || shouldShowDebug(state: state) else { return [] }

        return [
            EditorPanelSuggestion(
                id: "js.task-output",
                title: String(localized: "JS Output", table: "JSEditor"),
                systemImage: "terminal",
                placement: .bottom,
                order: 520,
                isPresented: { [weak self] _ in self?.shouldShowOutput == true },
                onDismiss: { _ in },
                content: { [weak self] state in
                    guard let self else { return AnyView(EmptyView()) }
                    return AnyView(
                        TaskOutputView(
                            taskManager: self.taskManager,
                            projectRoot: state.currentFileURL.flatMap { WorkspaceDetector.findRoot(from: $0)?.path }
                        )
                    )
                }
            ),
            EditorPanelSuggestion(
                id: "js.test-results",
                title: String(localized: "JS Tests", table: "JSEditor"),
                systemImage: "testtube.2",
                placement: .bottom,
                order: 530,
                isPresented: { [weak self] _ in self?.shouldShowTests == true },
                onDismiss: { _ in },
                content: { [weak self] _ in
                    guard let self else { return AnyView(EmptyView()) }
                    return AnyView(TestResultView(taskManager: self.taskManager))
                }
            ),
            EditorPanelSuggestion(
                id: "js.debug-toolbar",
                title: String(localized: "Debug", table: "JSEditor"),
                systemImage: "ladybug",
                placement: .bottom,
                order: 540,
                isPresented: { [weak self] state in self?.shouldShowDebug(state: state) == true },
                onDismiss: { _ in },
                content: { state in
                    let projectRoot = state.currentFileURL.flatMap { WorkspaceDetector.findRoot(from: $0)?.path }
                    return AnyView(DebugToolbarView(fileURL: state.currentFileURL, projectRoot: projectRoot))
                }
            ),
        ]
    }

    private var shouldShowOutput: Bool {
        taskManager.state != .idle || !taskManager.outputLines.isEmpty || !taskManager.issues.isEmpty
    }

    private var shouldShowTests: Bool {
        taskManager.state == .testing || !taskManager.testEvents.isEmpty
    }

    private func shouldShowDebug(state: EditorState) -> Bool {
        isJSLanguage(state.detectedLanguage?.tsName) && state.currentFileURL != nil
    }

    private func isJSLanguage(_ languageId: String?) -> Bool {
        languageId == "javascript" || languageId == "typescript"
    }
}
