import LumiKernel
import LumiUI

@MainActor
public final class ThemeMountainPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.theme.mountain"
    public let name = "Mountain Theme"
    public let order = 129
public static let policy: LumiPluginPolicy = .disabled

    public init() {}

    public func onReady(kernel: LumiKernel) throws {
        kernel.theme?.registerTheme(
            LumiUIThemeContribution(
                appTheme: MountainTheme(),
                editorThemeId: "mountain"
            )
        )
    }

    public func boot(kernel: LumiKernel) async throws {}
}