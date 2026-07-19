import LumiKernel
import LumiUI

@MainActor
public final class ThemeDraculaPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.theme.dracula"
    public let name = "Dracula Theme"
    public let order = 132

    public init() {}

    public func register(kernel: LumiKernel) throws {
        kernel.registerTheme(
            LumiUIThemeContribution(
                appTheme: DraculaTheme(),
                editorThemeId: "dracula"
            )
        )
    }

    public func boot(kernel: LumiKernel) async throws {}
}