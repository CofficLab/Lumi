import Foundation

actor ThemeVoidPlugin: SuperPlugin {
    static let shared = ThemeVoidPlugin()
    static let id: String = "void"
    static let displayName: String = "虚空深黑"
    static let description: String = "纯粹的虚空黑，深邃而神秘"
    static let iconName: String = "circle.fill"
    static let isConfigurable: Bool = false
    static let enable: Bool = true
    static var order: Int { 123 }

    nonisolated var instanceLabel: String { Self.id }

    @MainActor
    func addThemeContributions() -> [LumiUIThemeContribution] {
        [
            LumiUIThemeContribution(
                appTheme: VoidTheme(),
                editorThemeId: "void",
                editorThemeContributor: VoidSuperEditorThemeContributor(),
                fileIconThemeContributor: LumiFileIconThemeCatalog.void()
            )
        ]
    }
}
