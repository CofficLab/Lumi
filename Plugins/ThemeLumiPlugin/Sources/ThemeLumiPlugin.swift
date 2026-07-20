import LumiKernel
import LumiUI

@MainActor
public final class ThemeLumiPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.theme.lumi"
    public let name = "Lumi Theme"
    public let order = 100

    public init() {}

    public func register(kernel: LumiKernel) throws {
        kernel.theme?.registerTheme(
            LumiUIThemeContribution(
                appTheme: LumiTheme(),
                editorThemeId: "lumi-dark"
            )
        )
    }

    public func boot(kernel: LumiKernel) async throws {}
}