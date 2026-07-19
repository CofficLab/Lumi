import LumiKernel
import LumiUI

@MainActor
public final class ThemeStatusBarPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.theme-status-bar"
    public let name = "Theme Status Bar"
    public let order = 22  // 提前加载顺序，作为核心插件

    private var themeService: DefaultThemeProviding?

    public init() {}

    public func register(kernel: LumiKernel) throws {
        // 1. 注册 ThemeService（内核服务）
        let themeServiceInstance = DefaultThemeProviding()
        kernel.registerThemeService(themeServiceInstance)
        self.themeService = themeServiceInstance
    }

    public func boot(kernel: LumiKernel) async throws {}

    public func statusBarItems(kernel: LumiKernel) -> [StatusBarItem] {
        // ThemeProviding 不可用时显示错误视图
        guard let themeService = kernel.theme else {
            return [
                StatusBarItem(
                    id: "\(id).error",
                    title: "Theme",
                    systemImage: "exclamationmark.triangle.fill",
                    placement: .trailing,
                    statusBarView: { ThemeStatusBarErrorView(pluginName: self.name) }
                )
            ]
        }

        return [
            StatusBarItem(
                id: "\(id).switcher",
                title: "Theme",
                systemImage: "paintbrush",
                placement: .trailing,
                statusBarView: {
                    ThemeStatusBarView(themeService: themeService)
                }
            )
        ]
    }
}
