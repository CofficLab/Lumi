import Combine
import EditorContracts
import EditorService
import SwiftUI

public struct EditorWorkbenchView: View {
    @ObservedObject private var controller: EditorWorkspaceController
    @ObservedObject private var editorObserver: EditorServiceObserver
    private let surface: any EditorSurfaceProviding

    @State private var pendingCloseTabID: UUID?

    public init(
        controller: EditorWorkspaceController,
        surface: any EditorSurfaceProviding
    ) {
        self.controller = controller
        self.surface = surface
        _editorObserver = ObservedObject(wrappedValue: EditorServiceObserver(editor: controller.editor))
    }

    public var body: some View {
        VStack(spacing: 0) {
            if !controller.editor.sessions.tabs.isEmpty {
                EditorTabStripView(
                    controller: controller,
                    pendingCloseTabID: $pendingCloseTabID
                )
                Divider()
            }

            if let fileURL = controller.editor.files.currentFileURL {
                EditorBreadcrumbView(rootURL: controller.rootURL, fileURL: fileURL)
                Divider()
            }

            editorContent

            Divider()
            EditorStatusBarView(controller: controller)
        }
        .background(shortcutButtons)
        .confirmationDialog(
            "Save changes before closing?",
            isPresented: closeConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Save") { saveAndClosePendingTab() }
            Button("Don't Save", role: .destructive) { closePendingTab() }
            Button("Cancel", role: .cancel) { pendingCloseTabID = nil }
        } message: {
            Text("Your changes will be lost if you close this tab without saving.")
        }
    }

    @ViewBuilder
    private var editorContent: some View {
        if let error = controller.editor.files.fileLoadErrorMessage {
            ContentUnavailableView(
                "Unable to open file",
                systemImage: "exclamationmark.triangle",
                description: Text(error)
            )
        } else if controller.editor.files.isBinaryFile {
            ContentUnavailableView(
                "Binary file",
                systemImage: "doc.badge.ellipsis",
                description: Text("This file cannot be edited as text.")
            )
        } else {
            surface.makeEditorView()
        }
    }

    private var shortcutButtons: some View {
        HStack {
            Button("Save") { controller.editor.files.saveNow() }
                .keyboardShortcut("s", modifiers: .command)
            Button("Close Tab") {
                guard let id = controller.editor.sessions.activeSessionID else { return }
                requestClose(id)
            }
            .keyboardShortcut("w", modifiers: .command)
        }
        .frame(width: 0, height: 0)
        .opacity(0)
        .accessibilityHidden(true)
    }

    private var closeConfirmationPresented: Binding<Bool> {
        Binding(
            get: { pendingCloseTabID != nil },
            set: { if !$0 { pendingCloseTabID = nil } }
        )
    }

    private func requestClose(_ id: UUID) {
        guard let tab = controller.editor.sessions.tabs.first(where: { $0.id == id }) else { return }
        if tab.isDirty {
            controller.activateTab(id: id)
            pendingCloseTabID = id
        } else {
            controller.closeTab(id: id)
        }
    }

    private func closePendingTab() {
        guard let id = pendingCloseTabID else { return }
        pendingCloseTabID = nil
        controller.closeTab(id: id)
    }

    private func saveAndClosePendingTab() {
        guard let id = pendingCloseTabID else { return }
        controller.activateTab(id: id)
        controller.editor.files.saveNow()
        Task { @MainActor in
            for _ in 0..<200 {
                if !controller.editor.files.hasUnsavedChanges {
                    pendingCloseTabID = nil
                    controller.closeTab(id: id)
                    return
                }
                try? await Task.sleep(for: .milliseconds(10))
            }
            // Save failed or did not finish. Keep the tab open and dirty.
            pendingCloseTabID = nil
        }
    }
}

@MainActor
private final class EditorServiceObserver: ObservableObject {
    private var cancellable: AnyCancellable?

    init(editor: EditorService) {
        cancellable = editor.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }
}
