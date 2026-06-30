import Foundation
import LumiCoreKit
import SwiftUI

/// Web Search 插件。
///
/// 提供基础的网页搜索工具。
/// 主要用于满足阿里云 Qwen 系列模型对 Function Calling 的限制要求：
/// 当使用 web_extractor 或 web_fetch 工具时，必须同时声明 web_search 工具。
public enum WebSearchPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .general
    public static let iconName = "magnifyingglass"

    public static let info = LumiPluginInfo(
        id: "WebSearch",
        displayName: PluginWebSearchLocalization.string("Web Search"),
        description: PluginWebSearchLocalization.string("提供网页搜索功能支持，满足 Qwen 等模型的 Function Calling 限制。"),
        order: 101
    )

    public static var id: String { info.id }
    public static var displayName: String { info.displayName }
    public static var order: Int { info.order }

    @MainActor
    public static func agentTools(context: LumiPluginContext) -> [any LumiAgentTool] {
        [WebSearchTool()]
    }

        @MainActor
    public static func aboutView(context: LumiPluginContext) -> AnyView? {
        pluginAboutView(
            icon: iconName,
            displayName: info.displayName,
            description: info.description,
            kind: .general
        )
    }

}

enum PluginWebSearchLocalization {
    static let table = "Localizable"
    static let bundle = Bundle.module

    static func string(_ key: String) -> String {
        LumiPluginLocalization.string(key, bundle: Bundle.module, table: "Localizable")
    }
}
