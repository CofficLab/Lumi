import CodeEditSourceEditor
import Foundation

@MainActor
public enum EditorBuiltinSyntaxThemes {
    private static let lightThemeIDs: Set<String> = [
        "vscode-light",
        "github",
    ]

    private static let knownThemeIDs: [String] = [
        "xcode-dark",
        "lumi-dark",
        "midnight",
        "sky-dark",
        "aurora",
        "nebula",
        "void",
        "spring",
        "summer",
        "autumn",
        "winter",
        "github",
        "orchard",
        "mountain",
        "vscode-dark",
        "river",
        "vscode-light",
        "one-dark",
        "dracula",
    ]

    public static func registerAll(into registry: EditorExtensionRegistry) {
        for themeID in knownThemeIDs {
            let isDark = !lightThemeIDs.contains(themeID)
            registry.registerThemeContributor(BuiltinSyntaxThemeContributor(id: themeID, isDark: isDark))
        }
    }
}

@MainActor
private final class BuiltinSyntaxThemeContributor: SuperEditorThemeContributor {
    let id: String
    let isDark: Bool
    var displayName: String { id }
    var icon: String? { "paintpalette" }

    init(id: String, isDark: Bool) {
        self.id = id
        self.isDark = isDark
    }

    func createTheme() -> EditorTheme {
        isDark ? EditorThemeAdapter.fallbackTheme() : EditorThemeAdapter.lightTheme()
    }
}
