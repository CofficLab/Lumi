import AppKit
import Combine
import Foundation
import LumiCoreKit
import LumiUI
import SuperLogKit
import SwiftUI
import os

/// 防休眠插件：阻止系统休眠，支持定时和手动控制
public enum CaffeinatePlugin: LumiPlugin {
    public static var verbose: Bool { false }
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.caffeinate")

    public static let navigationId = "caffeinate_settings"

    public static let info = LumiPluginInfo(
        id: "Caffeinate",
        displayName: PluginCaffeinateLocalization.string("Anti-Sleep"),
        description: PluginCaffeinateLocalization.string("Prevent system sleep with timer and manual control"),
        order: 1,
        category: .system,
        policy: .optOut,
        stage: .beta,
        iconName: "bolt",
    )

    public static var id: String { info.id }
    public static var displayName: String { info.displayName }
    public static var description: String { info.description }
    public static var order: Int { info.order }
    public static var isConfigurable: Bool { policy.isConfigurable }

    @MainActor
    public static func menuBarPopupItems(context: LumiPluginContext) -> [LumiMenuBarPopupItem] {
        [
            LumiMenuBarPopupItem(id: "\(info.id).popup", order: Self.info.order) {
                CaffeinateMenuBarPopupView()
            }
        ]
    }

    @MainActor
    public static func agentTools(context: LumiPluginContext) -> [any LumiAgentTool] {
        [
            CaffeinateActivateTool(),
            CaffeinateDeactivateTool(),
            CaffeinateStatusTool(),
            CaffeinateTurnOffDisplayTool(),
        ]
    }

        @MainActor
    public static func pluginAboutView(context: LumiPluginContext) -> AnyView? {
        AnyView(CaffeinateAboutView())
    }

}

enum PluginCaffeinateLocalization {
    static let table = "Localizable"
    static let bundle = Bundle.module

    static func string(_ key: String) -> String {
        LumiPluginLocalization.string(key, bundle: Bundle.module, table: "Localizable")
    }
}
