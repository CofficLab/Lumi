import Foundation
import KernelCore
import os
import ProviderActivityBar
import KitSuperLog
import SwiftUI

@MainActor
public final class ActivityBarProvider: ActivityBarProviding, ObservableObject, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.activity-bar", category: "Provider")
    public nonisolated static let emoji = "🧱"
    nonisolated static let verbose = false

    /// 当前已激活入口的 id。
    @Published public private(set) var activeItemID: String?

    /// 当前已注入的全部 ActivityBar 项（按 `order` 排序）。
    @Published public private(set) var items: [ActivityBarItem] = []

    /// 已被业务插件追加/移除的入口历史（仅日志诊断用）。
    public private(set) var customItems: [ActivityBarItem] = []

    /// 隐藏缓存：按插件 id 存储被隐藏的入口，以便插件重新启用时恢复。
    private var hiddenItemCache: [String: [ActivityBarItem]] = [:]

    /// 入口被显式激活后的回调，由 PluginActivityBar 用于持久化全局激活态。
    var onActiveItemChanged: ((String?) -> Void)?

    public init() {}

    /// 用一组已存在的内容（即将被替换的旧 `DefaultActivityBarProviding` 数据）
    /// 预填新实例，确保 `unregisterProvider` 之后业务插件已注册的 `ActivityBarItem`
    /// 与激活态不会丢失。
    ///
    /// 调用场景：见 `PluginActivityBar.onBoot`——
    /// 多个业务插件（如 `PluginChatPanel`/`PluginDevice`/`PluginDiskManager`/...）
    /// 在 `onBoot` 中调用 `addItems(...)` 写入 ProviderFactory 预注册的默认实例；
    /// 本插件（`order=10`，晚于 `PluginChatPanel` 的 order=2）要在 `onBoot` 中
    /// `unregisterProvider` + `registerProvider` 替换为自定义实例。如果直接丢弃旧
    /// 实例，前序业务插件写入的 items 就会跟着默认实例一起被释放。
    ///
    /// - Parameters:
    ///   - items: 旧实例已注入的全部 ActivityBar 项（按 `order` 排序后传入，
    ///     调用方无需关心顺序）。
    ///   - activeItemID: 旧实例当前激活项；若传入 id 在 `items` 中不存在则被忽略。
    public convenience init(preloadedItems items: [ActivityBarItem], activeItemID: String? = nil) {
        self.init()
        // 走 `registerItems` 走默认路径（按 order 排序、激活态校验），复用本类统一逻辑。
        registerItems(items)
        if let activeItemID {
            activateItem(id: activeItemID)
        }
    }

    /// 注入/替换全部入口（按 `order` 排序，并校正激活态）。
    ///
    /// 完全自实现：与 `DefaultActivityBarProviding` 保持一致的排序与激活回退语义。
    public func registerItems(_ items: [ActivityBarItem]) {
        if Self.verbose {
            Self.logger.info("\(Self.t)替换入口：\(items.count, privacy: .public) 项")
        }
        let previousItems = self.items
        self.items = items.sorted { $0.order < $1.order }

        // 激活态校正：当前激活项若仍存在则保留，否则回退到首个（无入口时 nil）。
        let nextActiveID: String?
        if let activeItemID, self.items.contains(where: { $0.id == activeItemID }) {
            nextActiveID = activeItemID
        } else {
            nextActiveID = self.items.first?.id
        }
        setActiveItemID(nextActiveID, previousItems: previousItems)

        // 局部缓存，便于日志/调试观察。
        customItems = self.items
    }

    /// 追加入口，保留已有项。复用协议的默认合并实现。
    public func addItems(_ items: [ActivityBarItem]) {
        if Self.verbose {
            Self.logger.info("\(Self.t)追加入口：\(items.count, privacy: .public) 项")
        }
        var merged = self.items
        for item in items where !merged.contains(where: { $0.id == item.id }) {
            merged.append(item)
        }
        registerItems(merged)
    }

    /// 按 id 移除入口。复用协议默认实现。
    public func removeItems(ids: Set<String>) {
        if Self.verbose {
            Self.logger.info("\(Self.t)移除入口：\(ids.count, privacy: .public) 项")
        }
        registerItems(self.items.filter { !ids.contains($0.id) })
    }

    /// 激活指定入口。未知 id 忽略；传 nil 表示清除激活。
    public func activateItem(id: String?) {
        if Self.verbose {
            Self.logger.info("\(Self.t)activate: \(id ?? "nil", privacy: .public)")
        }
        guard id == nil || items.contains(where: { $0.id == id }) else { return }
        let previousID = activeItemID
        setActiveItemID(id)
        if previousID != activeItemID {
            onActiveItemChanged?(activeItemID)
        }
    }

    /// 返回 ActivityBar 视图（基于本类自渲染的竖直入口栏）。
    public func makeActivityBarView() -> AnyView {
        AnyView(ActivityBarView(provider: self))
    }

    /// 内置默认入口（已清空）。
    /// 业务插件通过各自的 onReady 注册自己的 ActivityBarItem。
    public func bootstrapBuiltInItems() {}

    // MARK: - Plugin Lifecycle Observation

    /// 按插件 id 隐藏入口：将该插件贡献的全部入口从可见列表移入隐藏缓存。
    ///
    /// 被隐藏的入口在插件重新启用时可通过 `restoreItems(forPluginID:)` 恢复。
    /// 内置入口（`ownerPluginID == nil`）不受影响。
    public func hideItems(forPluginID pluginID: String) {
        let hidden = items.filter { $0.ownerPluginID == pluginID }
        guard !hidden.isEmpty else { return }
        hiddenItemCache[pluginID, default: []].append(contentsOf: hidden)
        let idsToHide = Set(hidden.map(\.id))
        let remaining = items.filter { !idsToHide.contains($0.id) }
        registerItems(remaining)
        if Self.verbose {
            Self.logger.info("\(Self.t)隐藏插件 \(pluginID, privacy: .public) 的 \(hidden.count, privacy: .public) 个入口")
        }
    }

    /// 按插件 id 恢复之前被隐藏的入口。
    ///
    /// 插件重新启用时调用，将隐藏缓存中的入口重新合入可见列表。
    public func restoreItems(forPluginID pluginID: String) {
        guard let cached = hiddenItemCache.removeValue(forKey: pluginID), !cached.isEmpty else { return }
        addItems(cached)
        if Self.verbose {
            Self.logger.info("\(Self.t)恢复插件 \(pluginID, privacy: .public) 的 \(cached.count, privacy: .public) 个入口")
        }
    }

    // MARK: - Private

    /// 更新激活态，仅在实际变化时触发 `@Published` 变更，并通知状态发生变化的入口。
    private func setActiveItemID(_ id: String?, previousItems: [ActivityBarItem]? = nil) {
        guard activeItemID != id else { return }
        let previousID = activeItemID
        activeItemID = id

        if let previousID,
           let previousItem = (previousItems ?? items).first(where: { $0.id == previousID }) {
            previousItem.onActivationChanged(.deactivated)
        }

        if let id,
           let nextItem = items.first(where: { $0.id == id }), id != previousID {
            nextItem.onActivationChanged(.activated)
        }
    }
}
