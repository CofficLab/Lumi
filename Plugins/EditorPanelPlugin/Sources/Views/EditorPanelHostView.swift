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

    private let editorCore: EditorCore

    public init(
        projectPathStore: LumiCurrentProjectPathStore,
        editorCore: EditorCore
    ) {
        _projectVM = StateObject(wrappedValue: WindowProjectVM(store: projectPathStore))
        _editorContext = StateObject(
            wrappedValue: EditorContext(service: editorCore.editorService, themeVM: .shared)
        )
        self.editorCore = editorCore
    }

    public var body: some View {
        EditorWorkspaceView(service: editorCore.editorService)
            .environmentObject(projectVM)
            .environmentObject(themeVM)
            .environmentObject(conversationVM)
            .environmentObject(recentProjectsVM)
            .environmentObject(editorContext)
            .environmentObject(editorCore.editorService)
            .onAppear {
                editorCore.currentProjectPathProvider = { [projectVM] in
                    projectVM.currentProjectPath
                }
                EditorRuntimeBridge.configure(core: editorCore)
                syncEditorTheme()
            }
            .onChange(of: LumiUIThemeRegistry.shared.selectedThemeId) { _, _ in
                syncEditorTheme()
            }
    }

    private func syncEditorTheme() {
        let themeID = LumiUIThemeRegistry.shared.resolvedEditorThemeId(colorScheme: .dark) ?? "xcode-dark"
        editorCore.editorService.syncInitialThemeFromExternal(themeID)
    }
}
