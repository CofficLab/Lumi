import Foundation

@MainActor
public final class EditorThemeService {
    private let state: EditorState

    init(state: EditorState) {
        self.state = state
    }

    public var currentTheme: EditorTheme? { state.currentTheme }
    public var currentThemeId: String { state.currentThemeId }
    public var fontSize: Double { state.fontSize }
    public var tabWidth: Int { state.tabWidth }
    public var useSpaces: Bool { state.useSpaces }
    public var wrapLines: Bool { state.wrapLines }
    public var showMinimap: Bool { state.showMinimap }
    public var showGutter: Bool { state.showGutter }
    public var showFoldingRibbon: Bool { state.showFoldingRibbon }

    func setTheme(_ themeId: String) {
        state.setTheme(themeId)
    }

    func availableThemes() -> [any SuperEditorThemeContributor] {
        state.availableThemes()
    }

    public func syncInitialThemeFromExternal(_ editorThemeId: String) {
        state.syncInitialThemeFromExternal(editorThemeId)
    }
}
