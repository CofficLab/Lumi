import LumiKernel
import LumiUI

@MainActor
public final class ThemeSummerPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.theme.summer"
    public let name = "Summer Theme"
    public let order = 125

    public init() {}

    public func register(kernel: LumiKernel) throws {
        kernel.theme?.registerTheme(
            LumiUIThemeContribution(
                appTheme: SummerTheme(),
                editorThemeId: "summer"
            )
        )
    }

    public func boot(kernel: LumiKernel) async throws {}
}