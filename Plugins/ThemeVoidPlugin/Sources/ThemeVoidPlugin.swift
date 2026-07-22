import LumiKernel
import LumiUI

@MainActor
public final class ThemeVoidPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.theme.void"
    public let name = "Void Theme"
    public let order = 123
public static let policy: LumiPluginPolicy = .disabled

    public init() {}

    public func onReady(kernel: LumiKernel) throws {
        kernel.theme?.registerTheme(
            LumiUIThemeContribution(
                appTheme: VoidTheme(),
                editorThemeId: "void"
            )
        )
    }

    public func boot(kernel: LumiKernel) async throws {}
}