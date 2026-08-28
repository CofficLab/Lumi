import Foundation
import os
import ProviderLogo
import ProviderSettingView
import KitSuperLog
import SwiftUI

/// `SettingViewProviding` 的自研实现：持有设置入口项、选中状态和侧边栏 Logo。
///
/// 参照 `SettingsManager`（KernelLumi 体系）设计，迁移至 KernelCore 生态：
/// - 插件通过 `addEntries(_:)` 追加自己的设置入口（同 id 去重）；
/// - 消费方订阅 `objectWillChange` 即可感知入口集合变化；
/// - **侧边栏 Logo 是插件内部行为**：以「惰性闭包」延迟到 `makeSettingView()`
///   时从共享内核动态解析 `LogoProviding`，自行构建 Header，无需外部类型强转注入；
/// - 内置结构化日志，便于诊断注册 / 注销 / 选中切换。
@MainActor
public final class SettingViewManager: SettingViewProviding, ObservableObject, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.setting-view", category: "Plugin")
    public nonisolated static let emoji = "⚙️"
    nonisolated static let verbose = false

    @Published public private(set) var entries: [SettingEntryItem] = []
    @Published public private(set) var projectDetailSections: [ProjectDetailSectionItem] = []
    @Published public private(set) var selectedEntryID: String?

    /// 侧边栏 Header 需要的 Logo 服务来源。
    ///
    /// 采用「惰性闭包」而非固定注入实例：`LogoProviding` 会在启动阶段被
    /// `PluginLogoManager`（order=4）替换实现，Logo 贡献插件（如
    /// `LogoCofficPlugin` order=100）随后才注册。若在 `onBoot` 早期
    /// （order=3）就固定持有 `DefaultLogoProviding` 实例，将永远读不到
    /// 之后注册进新 `LogoManager` 的 Logo。因此在渲染时才动态解析，保证
    /// 拿到已装配好 Logo 贡献的最新实现。
    private let logoProvider: () -> (any LogoProviding)?

    public init(logoProvider: @escaping () -> (any LogoProviding)? = { nil }) {
        self.logoProvider = logoProvider
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

    public func addProjectDetailSections(_ newSections: [ProjectDetailSectionItem]) {
        var merged = projectDetailSections
        for section in newSections where !merged.contains(where: { $0.id == section.id }) {
            merged.append(section)
        }
        projectDetailSections = merged.sorted { $0.order < $1.order }
    }

    public func removeProjectDetailSections(ids: Set<String>) {
        projectDetailSections.removeAll { ids.contains($0.id) }
    }

    public func makeSettingView() -> AnyView {
        AnyView(SettingView(provider: self, logo: logoProvider()))
    }
}
