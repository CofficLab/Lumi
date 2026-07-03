import Foundation
import LumiCoreKit
import LumiUI
import SwiftUI

/// Web Fetch 插件。
///
/// 作为 package 化试点，插件适配层只负责把 `WebFetchTool` 注册到 Lumi 插件系统；
/// 实际网页抓取能力由 `WebFetchKit` 承载。
public enum WebFetchPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
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
        [WebFetchTool()]
    }

    @MainActor
    public static func aboutView(context: LumiPluginContext) -> AnyView? {
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

enum PluginWebFetchLocalization {
    static let table = "Localizable"
    static let bundle = Bundle.module

    static func string(_ key: String) -> String {
        LumiPluginLocalization.string(key, bundle: Bundle.module, table: "Localizable")
    }
}
