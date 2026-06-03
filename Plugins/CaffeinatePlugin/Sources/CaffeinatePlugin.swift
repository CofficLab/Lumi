import AgentToolKit
import AppKit
import Combine
import Foundation
import LumiCoreKit
import SwiftUI
import SuperLogKit
import os

/// 防休眠插件：阻止系统休眠，支持定时和手动控制
public actor CaffeinatePlugin: SuperPlugin, SuperLog {
    /// 插件专用 Logger
    nonisolated public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.caffeinate")

    // MARK: - Plugin Properties

    nonisolated public static let emoji = "☕️"

    nonisolated public static let verbose: Bool = true

    nonisolated public static let policy: PluginPolicy = .optOut

    public static let id: String = "Caffeinate"
    public static let navigationId: String = "caffeinate_settings"
    public static let displayName: String = PluginCaffeinateLocalization.string("Anti-Sleep")
    public static let description: String = PluginCaffeinateLocalization.string("Prevent system sleep with timer and manual control")

    public static func description(for language: LanguagePreference) -> String {
        PluginCaffeinateLocalization.string("Prevent system sleep with timer and manual control", for: language)
    }
    public static let iconName: String = "bolt"
    public static var category: PluginCategory { .system }
    public static var order: Int { 7 }

    // MARK: - Instance

    nonisolated public var instanceLabel: String { Self.id }
    public static let shared = CaffeinatePlugin()

    private init() {}

    // MARK: - UI Contributions

    /// 添加菜单栏弹窗视图
    /// - Returns: 要添加到菜单栏弹窗的视图，如果不需要则返回nil
    @MainActor public func addMenuBarPopupView() -> AnyView? {
        AnyView(CaffeinateMenuBarPopupView())
    }

    // MARK: - Agent Tools

    @MainActor
    public func agentTools(context: ToolContext) -> [SuperAgentTool] {
        [
            CaffeinateActivateTool(),
            CaffeinateDeactivateTool(),
            CaffeinateStatusTool(),
            CaffeinateTurnOffDisplayTool(),
        ]
    }
}

enum PluginCaffeinateLocalization {
    static let table = "Caffeinate"
    static let bundle = Bundle.module

    static func string(_ key: String) -> String {
        NSLocalizedString(key, tableName: table, bundle: bundle, value: key, comment: "")
    }

    static func string(_ key: String, for language: LanguagePreference) -> String {
        PackageStringLocalization.string(key, table: table, bundle: bundle, language: language)
    }
}
