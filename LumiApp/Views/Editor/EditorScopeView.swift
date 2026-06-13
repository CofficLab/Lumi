import EditorPanelPlugin
import EditorService
import LumiCoreKit
import LumiUI
import SwiftUI

struct EditorScopeView<Content: View>: View {
    @StateObject private var projectVM: WindowProjectVM
    @StateObject private var themeVM = AppThemeVM.shared
    @StateObject private var recentProjectsVM = AppProjectsVM.shared
    @StateObject private var conversationVM = WindowConversationVM()
    @StateObject private var editorContext: EditorContext

    private let editor: any LumiEditorServicing
    private let content: Content

    init(
        projectPathStore: LumiCurrentProjectPathStore,
        editor: any LumiEditorServicing,
        @ViewBuilder content: () -> Content
    ) {
        _projectVM = StateObject(wrappedValue: WindowProjectVM(store: projectPathStore))
        _editorContext = StateObject(
            wrappedValue: EditorContext(service: editor.editorService, themeVM: .shared)
        )
        self.editor = editor
        self.content = content()
    }

    var body: some View {
        content
            .environmentObject(projectVM)
            .environmentObject(themeVM)
            .environmentObject(conversationVM)
            .environmentObject(recentProjectsVM)
            .environmentObject(editorContext)
            .environmentObject(editor.editorService)
            .background {
                WindowToolbarSuppressor()
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
        let scheme = SystemAppearanceResolver.effectiveColorScheme
        let resolved = EditorSyntaxThemeResolver.resolve(
            registry: LumiUIThemeRegistry.shared,
            extensions: editor.extensionRegistry,
            colorScheme: scheme
        )
        editor.editorService.theme.syncInitialThemeFromExternal(resolved.id)
    }
}
