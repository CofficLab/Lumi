import LumiKernel
import LumiUI

@MainActor
public final class ThemeMountainPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.theme.mountain"
    public let name = "Mountain Theme"
    public let order = 129

    public init() {}

    public func register(kernel: LumiKernel) throws {
        kernel.theme?.registerTheme(
            LumiUIThemeContribution(
                appTheme: MountainTheme(),
                editorThemeId: "mountain"
            )
        )
    }

    public func boot(kernel: LumiKernel) async throws {}
}