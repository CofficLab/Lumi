import AgentToolKit
import Foundation
import LumiCoreKit
import SwiftUI

/// Web Fetch 插件。
///
/// 作为 package 化试点，插件适配层只负责把 `WebFetchTool` 注册到 Lumi 插件系统；
/// 实际网页抓取能力由 `WebFetchKit` 承载。
public enum WebFetchPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .optIn
    public static let category: LumiPluginCategory = .general
    public static let iconName = "globe"

    public static let info = LumiPluginInfo(
        id: "WebFetch",
        displayName: PluginWebFetchLocalization.string("Web Fetch"),
        description: PluginWebFetchLocalization.string("提供网页抓取和内容提取功能，支持 HTML 转 Markdown。"),
        order: 100
    )

    public static var id: String { info.id }
    public static var displayName: String { info.displayName }
    public static var order: Int { info.order }

    @MainActor
    public static func agentTools(context: LumiPluginContext) -> [any LumiAgentTool] {
        [WebFetchTool().asLumiAgentTool()]
    }

    @MainActor
    public static func aboutView(context: LumiPluginContext) -> AnyView? {
        pluginAboutView(
            features: [
                .init(icon: "globe", title: "Web Fetch", description: "提供网页抓取和内容提取功能，支持 HTML 转 Markdown。"),
                .init(icon: "puzzlepiece.extension", title: "Lumi Integration", description: "Integrates Web Fetch into the Lumi workspace"),
                .init(icon: "gearshape", title: "Configurable", description: "Enable or disable from plugin settings")
            ],
            steps: [
                "Enable Web Fetch in plugin settings",
                "The plugin registers its contributions when enabled",
                "Use the features provided in the Lumi workspace"
            ],
            tips: [
                "Toggle the plugin off if you do not need this feature",
                "Check plugin settings for additional options"
            ]
        )
    }

}

enum PluginWebFetchLocalization {
    static let table = "Localizable"
    static let bundle = Bundle.module

    static func string(_ key: String) -> String {
        LumiPluginLocalization.string(key, bundle: Bundle.module, table: "Localizable")
    }
}
