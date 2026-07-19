import LumiKernel
import LumiUI

@MainActor
public final class ThemeAutumnPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.theme.autumn"
    public let name = "Autumn Theme"
    public let order = 126

    public init() {}

    public func register(kernel: LumiKernel) throws {
        kernel.registerTheme(
            LumiUIThemeContribution(
                appTheme: AutumnTheme(),
                editorThemeId: "autumn"
            )
        )
    }

    public func boot(kernel: LumiKernel) async throws {}
}