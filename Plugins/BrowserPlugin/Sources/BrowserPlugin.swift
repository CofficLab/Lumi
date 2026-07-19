import Foundation
import LumiKernel

/// Browser 插件。
///
/// 提供网页截图与浏览器自动化功能。
/// - `browser_screenshot`：使用 WKWebView 渲染网页并截图
/// - `browser_agent`：基于 agent-browser CLI 的浏览器自动化
public enum BrowserPlugin: LumiPlugin {

    public static let info = LumiPluginInfo(
        id: "Browser",
        displayName: PluginBrowserLocalization.string("Browser"),
        description: PluginBrowserLocalization.string("提供网页截图与浏览器自动化功能，包括 WKWebView 截图和 agent-browser CLI 自动化。"),
        order: 102,
        category: .general,
        policy: .alwaysOn,
        stage: .beta,
        iconName: "safari",
    )

    public static var id: String { info.id }
    public static var displayName: String { info.displayName }
    public static var order: Int { info.order }

    @MainActor
    public static func agentTools(lumiCore: any LumiCoreAccessing) -> [any LumiAgentTool] {
        [
            BrowserScreenshotTool(),
            BrowserAgentTool(),
        ]
    }
}

enum PluginBrowserLocalization {
    static let table = "Localizable"
    static let bundle = Bundle.module

    static func string(_ key: String) -> String {
        LumiPluginLocalization.string(key, bundle: Bundle.module, table: "Localizable")
    }
}
