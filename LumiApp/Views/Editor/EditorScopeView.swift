import EditorPanelPlugin
import EditorService
import LumiCoreKit
import LumiUI
import SwiftUI

struct EditorScopeView<Content: View>: View {
    @StateObject private var themeVM = AppThemeVM.shared
    @ObservedObject private var themeRegistry = LumiUIThemeRegistry.shared
    @StateObject private var editorContext: EditorContext

    private let editor: any LumiEditorServicing
    private let content: Content

    init(
        editor: any LumiEditorServicing,
        @ViewBuilder content: () -> Content
    ) {
        _editorContext = StateObject(
            wrappedValue: EditorContext(service: editor.editorService, themeVM: .shared)
        )
        self.editor = editor
        self.content = content()
    }

    var body: some View {
        content
            .environmentObject(themeVM)
            .environmentObject(editorContext)
            .environmentObject(editor.editorService)
            .background {
                WindowToolbarSuppressor()
            }
            .onAppear {
                editor.currentProjectPathProvider = {
                    LumiCore.projectState?.currentProject?.path ?? ""
                }
                EditorRuntimeBridge.configure(editor: editor)
                syncEditorTheme()
            }
            .onChange(of: themeRegistry.selectedThemeId) { _, _ in
                syncEditorTheme()
            }
            .onChange(of: themeRegistry.systemColorScheme) { _, _ in
                syncEditorTheme()
            }
    }

    private func syncEditorTheme() {
        let scheme = AppThemeAppearanceResolver.effectiveColorScheme
        let resolved = EditorSyntaxThemeResolver.resolve(
            registry: LumiUIThemeRegistry.shared,
            extensions: editor.extensionRegistry,
            colorScheme: scheme
        )
        editor.editorService.theme.syncInitialThemeFromExternal(resolved.id)
    }
}
