import LumiKernel
import LumiUI

@MainActor
public final class ThemeMidnightPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.theme.midnight"
    public let name = "Midnight Theme"
    public let order = 120

    public init() {}

    public func register(kernel: LumiKernel) throws {
        kernel.registerTheme(
            LumiUIThemeContribution(
                appTheme: MidnightTheme(),
                editorThemeId: "midnight"
            )
        )
    }

    public func boot(kernel: LumiKernel) async throws {}
}