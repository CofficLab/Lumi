import Combine
import Foundation
import SwiftUI

// MARK: - Observation

/// Rail 视图状态变更事件。
///
/// 消费者通过 `addObserver` 注册回调，收到精准的"谁变了、变成什么"，
/// 避免只用 `objectWillChange` 粗粒度通知导致的不必要刷新与歧义。
@MainActor
public enum RailViewProvidingEvent {
    case tabsChanged([RailTabItem])
    case activeTabChanged(String?)
    case visibleCategoriesChanged(Set<RailViewCategory>)
    case visibleTabIDChanged(String?)
    case visibilityChanged(Bool)
    case widthChanged(RailViewWidth)
}

/// Rail 视图状态观察句柄。
@MainActor
public protocol RailViewProvidingObserverHandle: AnyObject {
    /// 停止接收后续 Rail 视图变更通知。重复调用无副作用。
    func cancel()
}

@MainActor
public final class NoopRailViewProvidingObserverHandle: RailViewProvidingObserverHandle {
    public init() {}
    public func cancel() {}
}

// MARK: - Rail Width

/// Rail 侧栏的宽度约束。
///
/// `idealWidth` 表示当前要应用的宽度；插件首次激活时它通常是插件提供的推荐值，
/// 有用户偏好时则是从磁盘恢复的值。
@MainActor
public struct RailViewWidth: Equatable, Sendable {
    public let minWidth: CGFloat
    public let idealWidth: CGFloat
    public let maxWidth: CGFloat

    public static let standard = Self(minWidth: 180, idealWidth: 240, maxWidth: 400)

    public init(minWidth: CGFloat, idealWidth: CGFloat, maxWidth: CGFloat) {
        let safeMin = minWidth.isFinite ? max(0, minWidth) : 0
        let safeMax: CGFloat
        if maxWidth.isFinite {
            safeMax = max(safeMin, maxWidth)
        } else {
            safeMax = .infinity
        }
        self.minWidth = safeMin
        self.maxWidth = safeMax
        self.idealWidth = Self.clamp(idealWidth, min: safeMin, max: safeMax)
    }

    public func withIdealWidth(_ width: CGFloat) -> Self {
        Self(minWidth: minWidth, idealWidth: width, maxWidth: maxWidth)
    }

    public func clamped(_ width: CGFloat) -> CGFloat {
        Self.clamp(width, min: minWidth, max: maxWidth)
    }

    private static func clamp(_ value: CGFloat, min minimum: CGFloat, max maximum: CGFloat) -> CGFloat {
        let safeValue = value.isFinite ? value : minimum
        return Swift.min(Swift.max(safeValue, minimum), maximum)
    }
}

/// Rail 宽度偏好的持久化接口。
///
/// 该接口由插件持有并注入 Rail provider；插件可以决定文件位置和存储生命周期。
@MainActor
public protocol RailViewWidthStoring: AnyObject {
    func loadWidth(ownerID: String) -> CGFloat?
    func saveWidth(_ width: CGFloat, ownerID: String)
    func removeWidth(ownerID: String)
}

/// 基于 binary plist 的 Rail 宽度存储。
///
/// 文件位置由插件通过 `fileURL` 注入，通常放在插件自己的数据目录。
@MainActor
public final class FileRailViewWidthStore: RailViewWidthStoring {
    private let fileURL: URL
    private var values: [String: Double]

    public init(fileURL: URL) {
        self.fileURL = fileURL
        self.values = Self.load(from: fileURL)
    }

    public func loadWidth(ownerID: String) -> CGFloat? {
        guard let value = values[ownerID], value.isFinite, value > 0 else { return nil }
        return CGFloat(value)
    }

    public func saveWidth(_ width: CGFloat, ownerID: String) {
        guard !ownerID.isEmpty, width.isFinite, width > 0 else { return }
        values[ownerID] = Double(width)
        persist()
    }

    public func removeWidth(ownerID: String) {
        guard values.removeValue(forKey: ownerID) != nil else { return }
        persist()
    }

    private func persist() {
        do {
            let directory = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try PropertyListSerialization.data(
                fromPropertyList: values,
                format: .binary,
                options: 0
            )
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // Keep the in-memory preference effective if the disk is unavailable.
        }
    }

    private static func load(from url: URL) -> [String: Double] {
        guard let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let values = plist as? [String: Double] else {
            return [:]
        }
        return values
    }
}

/// Rail（侧边栏）视图提供能力协议
///
/// 定义「内核 → 侧边栏 Rail 视图」这一段的最小契约：宿主在启动时
/// 通过内核解析 `RailViewProviding`，拿到 Rail 视图后放置到窗口左侧
/// （通常位于 ActivityBar 右侧、内容区左侧）。
///
/// 协议只声明能力，不关心具体实现：
/// - 外部通过 `registerTabs(_:)` 注入 `RailTabItem`；
/// - 实现负责把注入的 tabs 渲染成「标签栏 + 内容区」的 Rail 视图
///   （`makeRailView()`）。
///
/// 使用 `AnyView` 而非 `associatedtype`：协议可无泛型约束地作为存在类型
/// （`any RailViewProviding`）注册进 KernelCore 的 `[ObjectIdentifier: Any]` 注册表。
@MainActor
public protocol RailViewProviding: AnyObject {
    /// 当前已注入的全部 Rail tab 项。
    var tabs: [RailTabItem] { get }

    /// 当前允许展示的 Rail 分类。空集合表示不展示任何 Rail tab。
    var visibleCategories: Set<RailViewCategory> { get }

    /// 当前允许展示的 Rail tab id。为 nil 时不按 id 限制。
    var visibleTabID: String? { get }

    /// 当前激活的标签。
    var activeTabID: String? { get }

    /// 当前是否存在可见的 Rail tab。
    ///
    /// 根布局使用此状态决定是否为 Rail 保留空间；它只反映可见 tab，
    /// 不要求上层了解具体的 tab 分类或过滤规则。
    var hasVisibleTabs: Bool { get }

    /// 可见 tab 状态变化发布器。
    var railVisibilityPublisher: AnyPublisher<Bool, Never> { get }

    /// 当前 Rail 宽度（可能是插件推荐值，也可能是用户保存值）。
    var railWidth: RailViewWidth { get }

    /// Rail 宽度变化发布器。
    var railWidthPublisher: AnyPublisher<RailViewWidth, Never> { get }

    /// 注入 Rail tab 项（替换当前全部项）。
    func registerTabs(_ tabs: [RailTabItem])

    /// 追加插件贡献的标签，不覆盖其他插件的贡献。
    func addTabs(_ tabs: [RailTabItem])

    /// 按 id 撤回插件贡献的标签。
    func removeTabs(ids: Set<String>)

    /// 设置当前允许展示的 Rail 分类。
    func setVisibleCategories(_ categories: Set<RailViewCategory>)

    /// 设置当前允许展示的 Rail tab id。传入 nil 表示取消 id 限制。
    func setVisibleTabID(_ id: String?)

    /// 切换标签；未知 id 将被忽略。
    func activateTab(id: String?)

    /// 激活插件的 Rail 宽度配置。
    ///
    /// provider 会优先从插件注入的 store 恢复宽度；没有保存值时才使用
    /// `recommended` 的 `idealWidth`。owner ID 必须是插件稳定标识。
    func activateWidthProfile(
        ownerID: String,
        recommended: RailViewWidth,
        store: (any RailViewWidthStoring)?
    )

    /// 停用插件的 Rail 宽度配置。其他插件已经接管时不会覆盖其当前配置。
    func deactivateWidthProfile(ownerID: String)

    /// 保存当前激活插件的用户拖拽宽度。
    func saveCurrentWidth(_ width: CGFloat)

    /// 注册 Rail 视图状态变更观察者。
    ///
    /// 不应保存 Provider 的强引用；返回的句柄在释放或显式调用 `cancel()` 后
    /// 自动停止接收通知。
    @discardableResult
    func addObserver(_ callback: @escaping (RailViewProvidingEvent) -> Void) -> any RailViewProvidingObserverHandle

    /// 返回 Rail 视图（基于已注入的 tabs 渲染）。
    func makeRailView() -> AnyView
}

public extension RailViewProviding {
    var visibleCategories: Set<RailViewCategory> { Set(RailViewCategory.allCases) }

    var visibleTabID: String? { nil }

    var activeTabID: String? { nil }

    var hasVisibleTabs: Bool { !tabs.isEmpty }

    var railVisibilityPublisher: AnyPublisher<Bool, Never> {
        Just(hasVisibleTabs).eraseToAnyPublisher()
    }

    var railWidth: RailViewWidth { .standard }

    var railWidthPublisher: AnyPublisher<RailViewWidth, Never> {
        Just(railWidth).eraseToAnyPublisher()
    }

    func addTabs(_ newTabs: [RailTabItem]) {
        var merged = tabs
        for tab in newTabs where !merged.contains(where: { $0.id == tab.id }) {
            merged.append(tab)
        }
        registerTabs(merged)
    }

    func removeTabs(ids: Set<String>) {
        registerTabs(tabs.filter { !ids.contains($0.id) })
    }

    func setVisibleCategories(_ categories: Set<RailViewCategory>) {}

    func setVisibleTabID(_ id: String?) {}

    func activateTab(id: String?) {}

    func activateWidthProfile(ownerID: String, recommended: RailViewWidth) {
        activateWidthProfile(ownerID: ownerID, recommended: recommended, store: nil)
    }

    func activateWidthProfile(
        ownerID: String,
        recommended: RailViewWidth,
        store: (any RailViewWidthStoring)?
    ) {}

    func deactivateWidthProfile(ownerID: String) {}

    func saveCurrentWidth(_ width: CGFloat) {}

    @discardableResult
    func addObserver(_ callback: @escaping (RailViewProvidingEvent) -> Void) -> any RailViewProvidingObserverHandle {
        NoopRailViewProvidingObserverHandle()
    }
}
