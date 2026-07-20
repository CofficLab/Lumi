import LumiKernel
import LumiUI

@MainActor
public final class ThemeSpringPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.theme.spring"
    public let name = "Spring Theme"
    public let order = 124
public static let policy: LumiPluginPolicy = .disabled

    public init() {}

    public func register(kernel: LumiKernel) throws {
        kernel.theme?.registerTheme(
            LumiUIThemeContribution(
                appTheme: SpringTheme(),
                editorThemeId: "spring"
            )
        )
    }

    public func boot(kernel: LumiKernel) async throws {}
}