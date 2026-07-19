import LumiKernel
import LumiUI

@MainActor
public final class ThemeWinterPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.theme.winter"
    public let name = "Winter Theme"
    public let order = 127

    public init() {}

    public func register(kernel: LumiKernel) throws {
        kernel.registerTheme(
            LumiUIThemeContribution(
                appTheme: WinterTheme(),
                editorThemeId: "winter"
            )
        )
    }

    public func boot(kernel: LumiKernel) async throws {}
}