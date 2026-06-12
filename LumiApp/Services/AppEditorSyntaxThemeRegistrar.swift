import EditorService
import LumiUI

/// 将 LumiUI 主题目录同步到编辑器扩展注册表。
@MainActor
enum AppEditorSyntaxThemeRegistrar {
    static func sync(
        contributions: [LumiUIThemeContribution],
        into registry: EditorExtensionRegistry
    ) {
        EditorBuiltinSyntaxThemes.registerAppThemes(contributions, into: registry)
    }
}
