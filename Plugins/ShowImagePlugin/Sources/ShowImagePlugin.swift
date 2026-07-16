import Foundation
import LumiCoreKit
import SwiftUI

/// 图片显示插件。
///
/// 提供一个 `show_image` 工具，允许 LLM 在 UI 中展示图片。
/// 支持本地文件路径和远程 URL 两种图片源。
public enum ShowImagePlugin: LumiPlugin {

    public static let info = LumiPluginInfo(
        id: "ShowImage",
        displayName: PluginShowImageLocalization.string("Show Image"),
        description: PluginShowImageLocalization.string("Display images in the UI with support for local paths and remote URLs."),
        order: 97,
        category: .general,
        policy: .alwaysOn,
        stage: .beta,
        iconName: "photo.on.rectangle",
    )

    public static var id: String { info.id }
    public static var displayName: String { info.displayName }
    public static var order: Int { info.order }

    @MainActor
    public static func agentTools(context: LumiPluginContext) -> [any LumiAgentTool] {
        [ShowImageTool()]
    }

    @MainActor
    public static func rootOverlays(context: LumiPluginContext) -> [LumiRootOverlayItem] {
        [
            LumiRootOverlayItem(id: "\(info.id).overlay", order: info.order) { content in
                ShowImageOverlay { content }
            }
        ]
    }
}

enum PluginShowImageLocalization {
    static let table = "Localizable"
    static let bundle = Bundle.module

    static func string(_ key: String) -> String {
        LumiPluginLocalization.string(key, bundle: Bundle.module, table: "Localizable")
    }
}
