import LumiKernel
import LumiUI
import os

@MainActor
public final class ThemeOneDarkPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.theme.one-dark"
    public let name = "One Dark Theme"
    public let order = 131

    public init() {}

    public func register(kernel: LumiKernel) throws {
        kernel.registerTheme(
            LumiUIThemeContribution(
                appTheme: OneDarkTheme(),
                editorThemeId: "one-dark"
            )
        )
    }

    public func boot(kernel: LumiKernel) async throws {}
}