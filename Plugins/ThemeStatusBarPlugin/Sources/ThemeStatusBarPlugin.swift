import LumiKernel
import LumiUI

@MainActor
public final class ThemeStatusBarPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.theme-status-bar"
    public let name = "Theme Status Bar"
    public let order = 76

    public init() {}

    public func register(kernel: LumiKernel) throws {
        // Status bar items are registered in statusBarItems method
    }

    public func boot(kernel: LumiKernel) async throws {}

    public func statusBarItems(kernel: LumiKernel) -> [StatusBarItem] {
        // LumiThemeServicing 不可用时显示错误视图
        guard let themeService = kernel.theme else {
            return [
                StatusBarItem(
                    id: "\(id).error",
                    title: "Theme",
                    systemImage: "exclamationmark.triangle.fill",
                    placement: .trailing,
                    statusBarView: { ThemeStatusBarErrorView(pluginName: name) }
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
