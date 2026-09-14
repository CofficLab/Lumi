import Foundation
import KitSuperLog
import os
import ProviderToolbar
import SwiftUI

/// `ToolbarProviding` 的插件内自研实现。
///
/// 与 `ProviderToolbar.DefaultToolbarProviding` 语义等价，但由 `PluginToolbar`
/// 自行装配与注册（复刻 `PluginActivityBar` / `PluginLogoManager` 的替换范式）：
/// - 持有注入的 `ToolbarItem`，按 `placement` 渲染工具栏视图；
/// - 支持「基础可见分类」与「按来源临时隐藏分类」的叠加（多来源取并集）；
/// - 追踪各工具栏项的归属插件，自动隐藏已禁用插件的贡献，重新启用时恢复；
/// - 通过类型化观察事件通知 items / 可见分类变化，Kernel 不转发高频状态；
/// - 内置结构化日志，便于诊断注册、分类切换与视图刷新。
@MainActor
public final class ToolbarProvider: ToolbarProviding, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.toolbar", category: "Provider")
    public nonisolated static let emoji = "🧰"
    nonisolated static let verbose = false

    /// 当前已注入的全部工具栏项（按 `order` 升序）。
    public private(set) var toolbarItems: [ProviderToolbar.ToolbarItem] = []

    /// 当前经隐藏来源过滤后的可见分类。
    public private(set) var visibleCategories: Set<ProviderToolbar.ToolbarItemCategory>

    /// 工作区上下文设置的基础分类，不受临时隐藏请求影响。
    private var baseVisibleCategories: Set<ProviderToolbar.ToolbarItemCategory>

    /// 各来源的临时隐藏分类请求（取并集后作用于基础分类）。
    private var hiddenCategoriesBySource: [String: Set<ProviderToolbar.ToolbarItemCategory>] = [:]

    /// 内核当前已注册的全部插件 id，用于按 id 前缀推断工具栏项归属。
    private var knownPluginIDs: Set<String> = []

    /// 已禁用的插件 id：其贡献的工具栏项被隐藏，重新启用时自动恢复。
    private var disabledPluginIDs: Set<String> = []

    private var observers: [UUID: (ToolbarEvent) -> Void] = [:]

    /// - Parameters:
    ///   - preloadedItems: 即将被替换的旧实现中已注入的工具栏项。调用方无需关心
    ///     顺序，本类统一按 `order` 稳定排序。
    ///   - visibleCategories: 旧实现当前的可见分类，作为新的基础分类。
    public init(
        preloadedItems: [ProviderToolbar.ToolbarItem] = [],
        visibleCategories: Set<ProviderToolbar.ToolbarItemCategory> = Set(ToolbarItemCategory.allCases)
    ) {
        self.visibleCategories = visibleCategories
        self.baseVisibleCategories = visibleCategories
        self.toolbarItems = Self.sortedByOrder(preloadedItems)
    }

    // MARK: - Observation

    @discardableResult
    public func addToolbarObserver(
        _ callback: @escaping (ToolbarEvent) -> Void
    ) -> any ToolbarObserverHandle {
        let id = UUID()
        observers[id] = callback
        return ObserverHandle { [weak self] in
            self?.observers.removeValue(forKey: id)
        }
    }

    // MARK: - Items

    /// 当前经过分类过滤后的工具栏项。
    public var visibleToolbarItems: [ProviderToolbar.ToolbarItem] {
        toolbarItems.filter { visibleCategories.contains($0.category) }
    }

    /// 当前对视图可见的工具栏项：分类过滤之外，再排除已禁用插件的贡献。
    public var displayableToolbarItems: [ProviderToolbar.ToolbarItem] {
        visibleToolbarItems.filter { isDisplayable($0) }
    }

    /// 注入工具栏项（替换当前全部项）。
    public func registerToolbarItems(_ items: [ProviderToolbar.ToolbarItem]) {
        toolbarItems = items
        if Self.verbose {
            Self.logger.info("\(Self.t)替换工具栏项：\(items.count, privacy: .public) 项")
        }
        notify(.toolbarItemsChanged)
    }

    /// 追加工具栏项（保留已有项，同 id 去重并保留先注册者），随后按 `order` 稳定排序。
    public func addToolbarItems(_ newItems: [ProviderToolbar.ToolbarItem]) {
        var merged = toolbarItems
        for item in newItems where !merged.contains(where: { $0.id == item.id }) {
            merged.append(item)
        }
        registerToolbarItems(Self.sortedByOrder(merged))
    }

    /// 按 id 撤回插件贡献的工具栏项。
    public func removeToolbarItems(ids: Set<String>) {
        registerToolbarItems(toolbarItems.filter { !ids.contains($0.id) })
    }

    // MARK: - Plugin lifecycle

    /// 同步内核的插件启用状态，用于隐藏已禁用插件的工具栏贡献。
    ///
    /// 由 `PluginToolbar` 订阅 `PluginManaging` 后调用。这是插件忘记在 `onDisable`
    /// 撤回贡献时的兜底，保证工具栏不会残留已禁用插件的视图。
    ///
    /// - Parameters:
    ///   - knownPluginIDs: 内核当前已注册的全部插件 id。
    ///   - disabledPluginIDs: 其中处于禁用状态的插件 id。
    public func setPluginState(knownPluginIDs: Set<String>, disabledPluginIDs: Set<String>) {
        guard self.knownPluginIDs != knownPluginIDs || self.disabledPluginIDs != disabledPluginIDs else {
            return
        }
        self.knownPluginIDs = knownPluginIDs
        self.disabledPluginIDs = disabledPluginIDs
        if Self.verbose {
            Self.logger.info("\(Self.t)同步插件状态：known=\(knownPluginIDs.count, privacy: .public), disabled=\(disabledPluginIDs.count, privacy: .public)")
        }
        notify(.toolbarItemsChanged)
    }

    // MARK: - Categories

    /// 设置工作区允许展示的工具栏分类。
    public func setVisibleCategories(_ categories: Set<ProviderToolbar.ToolbarItemCategory>) {
        guard baseVisibleCategories != categories else { return }
        baseVisibleCategories = categories
        refreshVisibleCategories()
    }

    /// 为指定来源设置临时隐藏的工具栏分类，叠加在基础分类之上。
    ///
    /// 多个来源的隐藏分类取并集；传入空集合表示清除该来源的隐藏请求。
    public func setHiddenCategories(_ categories: Set<ProviderToolbar.ToolbarItemCategory>, for source: String) {
        if categories.isEmpty {
            hiddenCategoriesBySource.removeValue(forKey: source)
        } else {
            hiddenCategoriesBySource[source] = categories
        }
        refreshVisibleCategories()
    }

    // MARK: - View

    /// 返回工具栏视图（基于已注入的 items 渲染）。
    public func makeToolbarView() -> AnyView {
        AnyView(ToolbarView(provider: self))
    }

    // MARK: - Private

    /// 该项是否可显示：其归属插件未处于禁用状态。
    private func isDisplayable(_ item: ProviderToolbar.ToolbarItem) -> Bool {
        guard let owner = ownerPluginID(of: item) else { return true }
        return !disabledPluginIDs.contains(owner)
    }

    /// 解析工具栏项的归属插件。
    ///
    /// 优先使用显式的 `ownerPluginID`；缺省时按 id 前缀推断——插件贡献的工具栏项
    /// 普遍以自身插件 id 加 `.` 开头（如 `com.coffic.lumi.plugin.x.title`），
    /// 而内核已注册插件 id 可精确匹配出归属。取最长前缀命中，避免
    /// `com.a` 误配 `com.ab.x`。宿主贡献（如 `settings`）无匹配前缀，视为不受
    /// 插件生命周期管理，始终显示。
    ///
    /// 需要绕开该约定的插件可显式设置 `ToolbarItem.ownerPluginID`。
    private func ownerPluginID(of item: ProviderToolbar.ToolbarItem) -> String? {
        if let explicit = item.ownerPluginID { return explicit }
        return knownPluginIDs
            .filter { item.id.hasPrefix($0 + ".") }
            .max { $0.count < $1.count }
    }

    /// 按 `order` 升序稳定排序，`order` 相同时保留原始注册顺序。
    private static func sortedByOrder(_ items: [ProviderToolbar.ToolbarItem]) -> [ProviderToolbar.ToolbarItem] {
        items.enumerated()
            .sorted { lhs, rhs in
                if lhs.element.order != rhs.element.order {
                    return lhs.element.order < rhs.element.order
                }
                return lhs.offset < rhs.offset
            }
            .map(\.element)
    }

    /// 多来源隐藏分类取并集后从基础分类中扣除，仅在结果变化时通知。
    private func refreshVisibleCategories() {
        let hiddenCategories = hiddenCategoriesBySource.values.reduce(into: Set<ProviderToolbar.ToolbarItemCategory>()) {
            $0.formUnion($1)
        }
        let effectiveCategories = baseVisibleCategories.subtracting(hiddenCategories)
        guard visibleCategories != effectiveCategories else { return }
        visibleCategories = effectiveCategories
        notify(.visibleCategoriesChanged)
    }

    private func notify(_ event: ToolbarEvent) {
        observers.values.forEach { $0(event) }
    }

    private final class ObserverHandle: ToolbarObserverHandle {
        private var cancellation: (() -> Void)?

        init(cancellation: @escaping () -> Void) {
            self.cancellation = cancellation
        }

        func cancel() {
            cancellation?()
            cancellation = nil
        }
    }
}
