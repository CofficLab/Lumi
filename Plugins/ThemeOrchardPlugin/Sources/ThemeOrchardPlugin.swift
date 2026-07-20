import LumiKernel
import LumiUI

@MainActor
public final class ThemeOrchardPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.theme.orchard"
    public let name = "Orchard Theme"
    public let order = 128

    public init() {}

    public func register(kernel: LumiKernel) throws {
        kernel.theme?.registerTheme(
            LumiUIThemeContribution(
                appTheme: OrchardTheme(),
                editorThemeId: "orchard"
            )
        )
    }

    public func boot(kernel: LumiKernel) async throws {}
}