import LumiKernel
import LumiUI

@MainActor
public final class ThemeNebulaPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.theme.nebula"
    public let name = "Nebula Theme"
    public let order = 122
public static let policy: LumiPluginPolicy = .disabled

    public init() {}

    public func register(kernel: LumiKernel) throws {
        kernel.theme?.registerTheme(
            LumiUIThemeContribution(
                appTheme: NebulaTheme(),
                editorThemeId: "nebula"
            )
        )
    }

    public func boot(kernel: LumiKernel) async throws {}
}