import Foundation
import LumiKernel
import LumiUI
import SwiftUI

/// Web Search 插件。
///
/// 提供基础的网页搜索工具。
/// 主要用于满足阿里云 Qwen 系列模型对 Function Calling 的限制要求：
/// 当使用 web_extractor 或 web_fetch 工具时，必须同时声明 web_search 工具。
public enum WebSearchPlugin: LumiPlugin {

    public static let info = LumiPluginInfo(
        id: "WebSearch",
        displayName: PluginWebSearchLocalization.string("Web Search"),
        description: PluginWebSearchLocalization.string("提供网页搜索功能支持，满足 Qwen 等模型的 Function Calling 限制。"),
        order: 101,
        category: .general,
        policy: .alwaysOn,
        stage: .beta,
        iconName: "magnifyingglass",
    )

    public static var id: String { info.id }
    public static var displayName: String { info.displayName }
    public static var order: Int { info.order }

    @MainActor
    public static func agentTools(context: any LumiCoreAccessing) -> [any LumiAgentTool] {
        [WebSearchTool()]
    }

        @MainActor
    public static func pluginAboutView(context: any LumiCoreAccessing) -> AnyView? {
        AnyView(
            VStack(alignment: .leading, spacing: 16) {
                Text(info.displayName)
                    .font(.title2.weight(.semibold))
                Text(info.description)
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
            }
            .padding()
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
