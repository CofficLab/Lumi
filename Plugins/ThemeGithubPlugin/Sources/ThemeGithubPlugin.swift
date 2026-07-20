import LumiKernel
import LumiUI

@MainActor
public final class ThemeGithubPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.theme.github"
    public let name = "GitHub Theme"
    public let order = 128
public static let policy: LumiPluginPolicy = .disabled

    public init() {}

    public func register(kernel: LumiKernel) throws {
        kernel.theme?.registerTheme(
            LumiUIThemeContribution(
                appTheme: GitHubTheme(),
                editorThemeId: "github"
            )
        )
    }

    public func boot(kernel: LumiKernel) async throws {}
}