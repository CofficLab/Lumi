import LumiKernel
import LumiUI

@MainActor
public final class ThemeVscodePlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.theme.vscode"
    public let name = "VS Code Theme"
    public let order = 129

    public init() {}

    public func register(kernel: LumiKernel) throws {
        // Register VS Code themes
        kernel.registerTheme(
            LumiUIThemeContribution(
                appTheme: VscodeAutoTheme(),
                editorThemeId: "vscode-auto"
            )
        )
        kernel.registerTheme(
            LumiUIThemeContribution(
                appTheme: VscodeDarkTheme(),
                editorThemeId: "vscode-dark"
            )
        )
        kernel.registerTheme(
            LumiUIThemeContribution(
                appTheme: VscodeLightTheme(),
                editorThemeId: "vscode-light"
            )
        )
    }

    public func boot(kernel: LumiKernel) async throws {}
}
