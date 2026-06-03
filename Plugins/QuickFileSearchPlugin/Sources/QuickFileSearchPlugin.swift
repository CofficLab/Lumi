import Foundation
import LumiCoreKit
import SuperLogKit
import AgentToolKit
import SwiftUI
import LumiUI
import os

public enum QuickFileSearchBridge {
    public nonisolated(unsafe) static var activeWindowIdProvider: (@MainActor () -> UUID?)?
    public nonisolated(unsafe) static var selectFileHandler: (@MainActor (String, UUID?) -> Void)?
}

/// Quick File Search Plugin: 快速文件搜索插件
///
/// 功能：通过 Cmd+P 快捷键触发悬浮文件搜索框，快速定位和选择项目中的文件
public actor QuickFileSearchPlugin: SuperPlugin, SuperLog {
    public nonisolated static let policy: PluginPolicy = .disabled
    /// 插件专用 Logger
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.quick-file-search")

    // MARK: - Plugin Properties

    public nonisolated static let emoji = "🔍"
    public static var category: PluginCategory { .general }
    public nonisolated static let verbose: Bool = true

    public static let id = "QuickFileSearch"
    public static let displayName = String(localized: "Quick File Search", table: "QuickFileSearch")
    public static let description = String(localized: "Fast file search with Cmd+P", table: "QuickFileSearch")
    public static let iconName = "magnifyingglass"
    public static var order: Int { 50 }

    public nonisolated var instanceLabel: String { Self.id }

    public static let shared = QuickFileSearchPlugin()

    // MARK: - Lifecycle

    public nonisolated func onRegister() {
        if Self.verbose {
            if Self.verbose {
                            Self.logger.info("\(Self.t)📝 QuickFileSearchPlugin 已注册")
            }
        }
    }

    public nonisolated func onEnable() {
        Task { @MainActor in
            FileSearchHotkeyManager.shared.startMonitoring()
        }

        if Self.verbose {
            if Self.verbose {
                            Self.logger.info("\(Self.t)✅ QuickFileSearchPlugin 已启用，快捷键监听已启动")
            }
        }
    }

    public nonisolated func onDisable() {
        Task { @MainActor in
            FileSearchHotkeyManager.shared.stopMonitoring()
        }

        if Self.verbose {
            if Self.verbose {
                            Self.logger.info("\(Self.t)⛔️ QuickFileSearchPlugin 已禁用")
            }
        }
    }

    // MARK: - UI Contributions

    /// 提供根视图包裹层
    /// 包含悬浮搜索框的 ZStack overlay
    @MainActor
    public func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        AnyView(FileSearchOverlay(content: content()))
    }

    @MainActor
    public func agentTools(context: ToolContext) -> [SuperAgentTool] { [] }

    @MainActor
    public func sendMiddlewares() -> [AnySuperSendMiddleware] { [] }
}

// MARK: - Preview

#Preview("File Search Overlay") {
    FileSearchOverlay(content: Text(String(localized: "Content", table: "QuickFileSearch")))
        .inRootView()
}
