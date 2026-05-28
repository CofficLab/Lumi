import AgentToolKit
import Foundation
import LumiCoreKit
import LumiUI
import SuperLogKit
import SwiftUI
import os

/// 图片显示插件。
///
/// 提供一个 `show_image` 工具，允许 LLM 在 UI 中展示图片。
/// 支持本地文件路径和远程 URL 两种图片源。
///
/// ## 架构
///
/// - `ShowImageState`（@MainActor 单例）：存储图片显示状态
/// - `ShowImagePlugin`（Actor）：插件主体，提供 `addRootView` 和工具
/// - `ShowImageOverlay`（View）：通过 `addRootView` 挂载，监听图片显示状态变化
/// - `ShowImageTool`：接收图片路径/URL，触发图片显示
public actor ShowImagePlugin: SuperPlugin, SuperLog {
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.show-image")

    public nonisolated static let emoji = "🖼️"
    public nonisolated static let verbose: Bool = true

    public static let id: String = "ShowImage"
    public static let displayName: String = PluginShowImageLocalization.string("Show Image")
    public static let description: String = PluginShowImageLocalization.string("Display images in the UI with support for local paths and remote URLs.")

    public static func description(for language: LanguagePreference) -> String {
        PluginShowImageLocalization.string("Display images in the UI with support for local paths and remote URLs.", for: language)
    }
    public static let iconName: String = "photo.on.rectangle"
    public static var category: PluginCategory { .integration }
    public static var order: Int { 97 }

    nonisolated public var instanceLabel: String { Self.id }

    public static let shared = ShowImagePlugin()

    private init() {}

    nonisolated public func onRegister() {
        if Self.verbose {
            Self.logger.info("\(Self.t)📝 已注册")
        }
    }

    nonisolated public func onEnable() {
        if Self.verbose {
            Self.logger.info("\(Self.t)✅ 已启用")
        }
    }

    nonisolated public func onDisable() {
        if Self.verbose {
            Self.logger.info("\(Self.t)⛔️ 已禁用")
        }
    }

    @MainActor
    public func addRootView<Content: View>(@ViewBuilder content: () -> Content) -> AnyView? {
        AnyView(ShowImageOverlay { content() })
    }

    @MainActor
    public func agentTools(context: ToolContext) -> [SuperAgentTool] {
        [ShowImageTool()]
    }
}

enum PluginShowImageLocalization {
    static let table = "ShowImage"
    static let bundle = Bundle.module

    static func string(_ key: String) -> String {
        NSLocalizedString(key, tableName: table, bundle: bundle, value: key, comment: "")
    }

    static func string(_ key: String, for language: LanguagePreference) -> String {
        PackageStringLocalization.string(key, table: table, bundle: bundle, language: language)
    }
}
