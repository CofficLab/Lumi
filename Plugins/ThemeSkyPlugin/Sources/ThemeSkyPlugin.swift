import LumiKernel
import LumiUI

@MainActor
public final class ThemeSkyPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.theme.sky"
    public let name = "Sky Theme"
    public let order = 120
public static let policy: LumiPluginPolicy = .disabled

    public init() {}

    public func onReady(kernel: LumiKernel) throws {
        kernel.theme?.registerTheme(
            LumiUIThemeContribution(
                appTheme: SkyTheme(),
                editorThemeId: "sky-dark"
            )
        )
    }

    public func boot(kernel: LumiKernel) async throws {}
}