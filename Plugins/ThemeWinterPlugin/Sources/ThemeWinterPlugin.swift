import LumiKernel
import LumiUI

@MainActor
public final class ThemeWinterPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.theme.winter"
    public let name = "Winter Theme"
    public let order = 127
public static let policy: LumiPluginPolicy = .disabled

    public init() {}

    public func register(kernel: LumiKernel) throws {
        kernel.theme?.registerTheme(
            LumiUIThemeContribution(
                appTheme: WinterTheme(),
                editorThemeId: "winter"
            )
        )
    }

    public func boot(kernel: LumiKernel) async throws {}
}