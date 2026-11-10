import SwiftUI

/// `ContentViewProviding` 的默认实现：持有当前主内容视图。
///
/// 插件通过 `setContentView(_:)` 注册主要内容（如设备信息视图）；
/// 未设置时 `makeContentView()` 返回占位提示。
@MainActor
public final class DefaultContentViewProviding: ContentViewProviding {
    public private(set) var tabs: [ContentTabItem] = []
    public private(set) var isDemoMode = false
    private struct Entry: Identifiable {
        let id: String
        let order: Int
        let view: AnyView
    }

    fileprivate var contentView: AnyView?
    private var entries: [Entry] = []
    private var observers: [UUID: (ContentViewEvent) -> Void] = [:]

    // MARK: - Internal State Projection

    // 以下只读投影供 `@testable` 断言内部状态机使用，不参与业务逻辑：
    // 渲染路径统一走 `renderedContent`，避免测试依赖 SwiftUI 视图结构。

    /// 当前实际参与渲染的内容视图（entries 优先，回落到单内容通道）。
    var currentRenderedContent: AnyView? { renderedContent }

    /// entries 通道的 id，按 order 升序。
    var renderedIDs: [String] { entries.map(\.id) }

    /// entries 通道的 order，按当前排序。
    var entryOrders: [Int] { entries.map(\.order) }

    /// 单内容通道是否为空。
    var singleContentIsNil: Bool { contentView == nil }

    public init() {}

    public func setDemoMode(_ enabled: Bool) {
        isDemoMode = enabled
    }

    public func setTabs(_ tabs: [ContentTabItem]) {
        self.tabs = tabs.sorted { $0.order < $1.order }
        removeAllContentView()
        for tab in self.tabs {
            addContentView(tab.content, id: tab.id, order: tab.order)
        }
    }

    @discardableResult
    public func addContentViewObserver(
        _ callback: @escaping (ContentViewEvent) -> Void
    ) -> any ContentViewObserverHandle {
        let id = UUID()
        observers[id] = callback
        return ObserverHandle { [weak self] in
            self?.observers.removeValue(forKey: id)
        }
    }

    public func setContentView(_ view: AnyView?) {
        entries.removeAll()
        contentView = view
        observers.values.forEach { $0(.contentChanged) }
    }

    public func addContentView(_ view: AnyView, id: String, order: Int) {
        var updated = entries.filter { $0.id != id }
        updated.append(Entry(id: id, order: order, view: view))
        updated.sort { $0.order < $1.order }
        entries = updated
        contentView = nil
        observers.values.forEach { $0(.contentChanged) }
    }

    public func removeContentView(id: String) {
        let originalCount = entries.count
        entries.removeAll { $0.id == id }
        guard entries.count != originalCount else { return }
        observers.values.forEach { $0(.contentChanged) }
    }

    public func removeAllContentView() {
        guard !entries.isEmpty || contentView != nil else { return }
        entries.removeAll()
        contentView = nil
        observers.values.forEach { $0(.contentChanged) }
    }

    public func makeContentView() -> AnyView {
        AnyView(ContentHostView(provider: self))
    }

    fileprivate var renderedContent: AnyView? {
        if entries.isEmpty {
            return contentView
        }

        return AnyView(
            VStack(spacing: 0) {
                ForEach(entries) { entry in
                    entry.view
                }
            }
        )
    }

    private final class ObserverHandle: ContentViewObserverHandle {
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

/// Compatibility name used by older Lumi/Cisum factories.
public typealias DefaultContentViewProvider = DefaultContentViewProviding

/// 稳定挂在 RootView 中并观察 Provider；后续 `setContentView` 会直接刷新内容区。
private struct ContentHostView: View {
    let provider: DefaultContentViewProviding
    @State private var observationRevision = 0
    @State private var observerHandle: (any ContentViewObserverHandle)?

    var body: some View {
        Group {
            if let contentView = provider.renderedContent {
                contentView
            } else {
                ContentPlaceholderView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .id(observationRevision)
        .onAppear {
            guard observerHandle == nil else { return }
            observerHandle = provider.addContentViewObserver { _ in
                observationRevision += 1
            }
        }
        .onDisappear {
            observerHandle?.cancel()
            observerHandle = nil
        }
    }
}

/// 内容区占位视图。
private struct ContentPlaceholderView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "macwindow")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text(pluginLocalization.string("No plugin view registered"))
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(pluginLocalization.string("A plugin must register a main content view for this workspace."))
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
