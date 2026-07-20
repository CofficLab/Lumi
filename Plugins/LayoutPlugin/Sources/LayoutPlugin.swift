import LumiKernel
import SuperLogKit
import SwiftUI
import os

/// 布局持久化插件
///
/// 负责监听内核 `LumiLayoutState` 发出的事件通知，
/// 将布局变化持久化到磁盘，并在 App 启动时从磁盘恢复。
///
/// 内核只提供状态和发出事件，不感知插件存在。
/// 插件通过 `NotificationCenter` 监听事件并执行持久化。
@MainActor
public final class LayoutPlugin: LumiPlugin {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.layout")
    nonisolated static let emoji = "📐"
    nonisolated static let verbose = false

    public let id = "com.coffic.lumi.plugin.layout"
    public let name = "Layout Persistence"
    public let order = 99
public static let policy: LumiPluginPolicy = .disabled

    public init() {}

    public func register(kernel: LumiKernel) throws {
        // Layout persistence is handled in boot phase
    }

    public func boot(kernel: LumiKernel) async throws {
        if Self.verbose {
            Self.logger.info("\(Self.t)boot，开始恢复布局")
        }
        LayoutPersistenceCoordinator.shared.restore()
    }

    public func titleToolbarItems(kernel: LumiKernel) -> [TitleToolbarItem] {
        [
            TitleToolbarItem(
                id: "\(id).layout-menu",
                title: "Layout",
                placement: .trailing
            ) {
                // LayoutMenuButton needs to be updated to accept kernel instead of lumiCore
                // For now, return a placeholder
                Text("Layout")
            }
        ]
    }
}
