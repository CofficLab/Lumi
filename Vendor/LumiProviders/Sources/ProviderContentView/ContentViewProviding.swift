import SwiftUI

/// 主内容视图提供能力协议
///
/// 定义「内核 → 主内容区」这一段的最小契约：插件（如 DevicePlugin）在
/// `onBoot` 中解析 `ContentViewProviding`，通过 `setContentView(_:)`
/// 注册自己的主要内容；RootView 的内容区据此渲染。
///
/// 协议只声明能力，不关心具体实现。
///
/// 使用 `AnyView` 而非 `associatedtype`：协议可无泛型约束地作为存在类型
/// （`any ContentViewProviding`）注册进 KernelCore 的 `[ObjectIdentifier: Any]` 注册表。
@MainActor
public enum ContentViewEvent {
    case contentChanged
}

/// Compatibility tab contribution used by older Lumi/Cisum hosts.
@MainActor
public struct ContentTabItem: Identifiable {
    public let id: String
    public let title: String
    public let order: Int
    public let content: AnyView

    public init(id: String, title: String, order: Int, content: AnyView) {
        self.id = id
        self.title = title
        self.order = order
        self.content = content
    }
}

@MainActor
public protocol ContentViewObserverHandle: AnyObject {
    func cancel()
}

@MainActor
public protocol ContentViewProviding: AnyObject {
    var tabs: [ContentTabItem] { get }
    var isDemoMode: Bool { get }

    func setTabs(_ tabs: [ContentTabItem])
    func setDemoMode(_ enabled: Bool)

    @discardableResult
    func addContentViewObserver(
        _ callback: @escaping (ContentViewEvent) -> Void
    ) -> any ContentViewObserverHandle

    /// 设置当前主内容视图（传 `nil` 表示清空，回退到占位）。
    func setContentView(_ view: AnyView?)

    /// 兼容旧版多内容区 API：注册一块按顺序排列的内容。
    func addContentView(_ view: AnyView, id: String, order: Int)

    /// 兼容旧版多内容区 API：移除指定内容块。
    func removeContentView(id: String)

    /// 兼容旧版多内容区 API：移除全部内容块。
    func removeAllContentView()

    /// 返回当前主内容视图；未设置时返回占位视图。
    func makeContentView() -> AnyView
}

public extension ContentViewProviding {
    var tabs: [ContentTabItem] { [] }
    var isDemoMode: Bool { false }
    func setTabs(_ tabs: [ContentTabItem]) {
        removeAllContentView()
        for tab in tabs.sorted(by: { $0.order < $1.order }) {
            addContentView(tab.content, id: tab.id, order: tab.order)
        }
    }
    func setDemoMode(_ enabled: Bool) {}

    func addContentView(_ view: AnyView, id: String, order: Int) {
        setContentView(view)
    }

    func removeContentView(id: String) {
        setContentView(nil)
    }

    func removeAllContentView() {
        setContentView(nil)
    }

    @discardableResult
    func addContentViewObserver(
        _ callback: @escaping (ContentViewEvent) -> Void
    ) -> any ContentViewObserverHandle {
        NoopContentViewObserverHandle()
    }
}

@MainActor
private final class NoopContentViewObserverHandle: ContentViewObserverHandle {
    func cancel() {}
}
