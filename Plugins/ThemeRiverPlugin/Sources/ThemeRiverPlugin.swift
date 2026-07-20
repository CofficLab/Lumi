import LumiKernel
import LumiUI

@MainActor
public final class ThemeRiverPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.theme.river"
    public let name = "River Theme"
    public let order = 130
public static let policy: LumiPluginPolicy = .disabled

    public init() {}

    public func register(kernel: LumiKernel) throws {
        kernel.theme?.registerTheme(
            LumiUIThemeContribution(
                appTheme: RiverTheme(),
                editorThemeId: "river"
            )
        )
    }

    public func boot(kernel: LumiKernel) async throws {}
}