import Foundation
import os
import ProviderSettingView
import SuperLogKit
import SwiftUI

/// `SettingViewProviding` 的自研实现：持有设置入口项、选中状态和侧边栏 Header。
///
/// 复刻旧版 `SettingsManager`（KernelLumi 体系），迁移至 KernelCore 生态：
/// - 插件通过 `addEntries(_:)` 追加自己的设置入口（同 id 去重）；
/// - 消费方订阅 `objectWillChange` 即可感知入口集合变化；
/// - 内置结构化日志，便于诊断注册 / 注销 / 选中切换。
@MainActor
public final class SettingViewManager: SettingViewProviding, ObservableObject, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.setting-view", category: "Plugin")
    public nonisolated static let emoji = "⚙️"
    nonisolated static let verbose = false

    @Published public private(set) var entries: [SettingEntryItem] = []
    @Published public private(set) var selectedEntryID: String?
    @Published public private(set) var sidebarHeader: AnyView?

    public init() {}

    /// 注入侧边栏顶部 Header（如 Logo + 应用名 + 版本）。
    public func setSidebarHeader(_ view: AnyView?) {
        if Self.verbose {
            Self.logger.info("\(Self.t)setSidebarHeader: \(view == nil ? "nil" : "set", privacy: .public)")
        }
        sidebarHeader = view
    }

    public func registerEntries(_ entries: [SettingEntryItem]) {
        if Self.verbose {
            Self.logger.info("\(Self.t)registerEntries: \(entries.count, privacy: .public) 项")
        }
        self.entries = entries.sorted { $0.order < $1.order }
        if selectedEntryID == nil || !self.entries.contains(where: { $0.id == selectedEntryID }) {
            selectedEntryID = self.entries.first?.id
        }
    }

    public func selectEntry(id: String?) {
        guard selectedEntryID != id else { return }
        if Self.verbose {
            Self.logger.info("\(Self.t)selectEntry: \(id ?? "nil", privacy: .public)")
        }
        selectedEntryID = id
    }

    public func makeSettingView() -> AnyView {
        ProviderSettingView.makeSettingView(provider: self)
    }
}
