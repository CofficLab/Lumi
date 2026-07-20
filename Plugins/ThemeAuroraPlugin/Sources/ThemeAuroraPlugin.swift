import LumiKernel
import LumiUI

@MainActor
public final class ThemeAuroraPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.theme.aurora"
    public let name = "Aurora Theme"
    public let order = 121

    public init() {}

    public func register(kernel: LumiKernel) throws {
        kernel.theme?.registerTheme(
            LumiUIThemeContribution(
                appTheme: AuroraTheme(),
                editorThemeId: "aurora"
            )
        )
    }

    public func boot(kernel: LumiKernel) async throws {}
}