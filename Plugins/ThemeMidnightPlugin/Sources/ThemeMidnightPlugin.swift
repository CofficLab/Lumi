import LumiKernel
import LumiUI

@MainActor
public final class ThemeMidnightPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.theme.midnight"
    public let name = "Midnight Theme"
    public let order = 120
public static let policy: LumiPluginPolicy = .disabled

    public init() {}

    public func onReady(kernel: LumiKernel) throws {
        kernel.theme?.registerTheme(
            LumiUIThemeContribution(
                appTheme: MidnightTheme(),
                editorThemeId: "midnight"
            )
        )
    }

    public func boot(kernel: LumiKernel) async throws {}
}