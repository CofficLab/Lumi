import EditorService
import LumiCoreKit
import LumiUI
import SwiftUI

public struct EditorPanelHostView: View {
    @StateObject private var projectVM: WindowProjectVM
    @StateObject private var themeVM = AppThemeVM.shared
    @StateObject private var recentProjectsVM = AppProjectsVM.shared
    @StateObject private var conversationVM = WindowConversationVM()
    @StateObject private var editorContext: EditorContext

    private let editor: any LumiEditorServicing

    public init(
        projectPathStore: LumiCurrentProjectPathStore,
        editor: any LumiEditorServicing
    ) {
        _projectVM = StateObject(wrappedValue: WindowProjectVM(store: projectPathStore))
        _editorContext = StateObject(
            wrappedValue: EditorContext(service: editor.editorService, themeVM: .shared)
        )
        self.editor = editor
    }

    public var body: some View {
        EditorWorkspaceView(service: editor.editorService)
            .environmentObject(projectVM)
            .environmentObject(themeVM)
            .environmentObject(conversationVM)
            .environmentObject(recentProjectsVM)
            .environmentObject(editorContext)
            .environmentObject(editor.editorService)
            .background {
                EditorWindowToolbarSuppressor()
            }
            .onAppear {
                editor.currentProjectPathProvider = { [projectVM] in
                    projectVM.currentProjectPath
                }
                EditorRuntimeBridge.configure(editor: editor)
                syncEditorTheme()
            }
            .onChange(of: LumiUIThemeRegistry.shared.selectedThemeId) { _, _ in
                syncEditorTheme()
            }
    }

    private func syncEditorTheme() {
        let themeID = LumiUIThemeRegistry.shared.resolvedEditorThemeId(colorScheme: .dark) ?? "xcode-dark"
        editor.editorService.syncInitialThemeFromExternal(themeID)
    }
}

/// Prevents SwiftUI `.toolbar` or other editor chrome from attaching an NSToolbar
/// that overlaps the app-level custom title toolbar.
private struct EditorWindowToolbarSuppressor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        clearToolbar(from: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        clearToolbar(from: nsView)
    }

    private func clearToolbar(from view: NSView) {
        DispatchQueue.main.async {
            view.window?.toolbar = nil
        }
    }
}
