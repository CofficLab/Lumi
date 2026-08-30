import Combine
import LumiUI
import ProviderConversation
import SwiftUI

@MainActor
public final class DefaultChatSectionProviding: ChatSectionProviding, ObservableObject {
    @Published public private(set) var isVisible: Bool = true
    @Published public private(set) var isContextActive: Bool = false
    @Published public private(set) var activeContext: ChatContext? = .defaultChat
    @Published public private(set) var isHeaderVisible: Bool = true
    @Published public private(set) var items: [ChatSectionItem] = []
    @Published public private(set) var barItems: [ChatSectionBarItem] = []
    @Published public private(set) var rootWrappers: [ChatSectionRootWrapper] = []

    /// 会话选择绑定订阅：随 Provider 生命周期持有（与内核同生命周期）。
    private var conversationSelectionCancellable: AnyCancellable?
    private var observers: [WeakObserver] = []

    public init() {}

    public func addItems(_ newItems: [ChatSectionItem]) {
        var byID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        for item in newItems { byID[item.id] = item }
        items = byID.values.sorted { $0.order == $1.order ? $0.id < $1.id : $0.order < $1.order }
        notify(.itemsChanged(items))
    }

    public func removeItem(id: String) {
        let oldCount = items.count
        items.removeAll { $0.id == id }
        if items.count != oldCount { notify(.itemsChanged(items)) }
    }

    public func addBarItems(_ newItems: [ChatSectionBarItem]) {
        var byID = Dictionary(uniqueKeysWithValues: barItems.map { ($0.id, $0) })
        for item in newItems { byID[item.id] = item }
        barItems = byID.values.sorted { $0.order == $1.order ? $0.id < $1.id : $0.order < $1.order }
        notify(.barItemsChanged(barItems))
    }

    public func removeBarItem(id: String) {
        let oldCount = barItems.count
        barItems.removeAll { $0.id == id }
        if barItems.count != oldCount { notify(.barItemsChanged(barItems)) }
    }

    public func addRootWrappers(_ newWrappers: [ChatSectionRootWrapper]) {
        var byID = Dictionary(uniqueKeysWithValues: rootWrappers.map { ($0.id, $0) })
        for wrapper in newWrappers { byID[wrapper.id] = wrapper }
        rootWrappers = byID.values.sorted { $0.order == $1.order ? $0.id < $1.id : $0.order < $1.order }
        notify(.rootWrappersChanged(rootWrappers))
    }

    public func removeRootWrapper(id: String) {
        let oldCount = rootWrappers.count
        rootWrappers.removeAll { $0.id == id }
        if rootWrappers.count != oldCount { notify(.rootWrappersChanged(rootWrappers)) }
    }

    public func setVisible(_ visible: Bool) {
        guard isVisible != visible else { return }
        isVisible = visible
        notify(.visibilityChanged(visible))
    }

    public func setContextActive(_ active: Bool) {
        guard isContextActive != active else { return }
        isContextActive = active
        notify(.contextActiveChanged(active))
    }

    public func setActiveContext(_ context: ChatContext?) {
        guard activeContext != context else { return }
        activeContext = context
        notify(.activeContextChanged(context))
    }

    public func setHeaderVisible(_ visible: Bool) {
        guard isHeaderVisible != visible else { return }
        isHeaderVisible = visible
        notify(.headerVisibilityChanged(visible))
    }

    @discardableResult
    public func addObserver(_ callback: @escaping (ChatSectionProvidingEvent) -> Void) -> any ChatSectionProvidingObserverHandle {
        let observer = Observer(owner: self, callback: callback)
        observers.append(WeakObserver(observer))
        return observer
    }

    private func remove(_ observer: Observer) {
        observers.removeAll { $0.observer === observer }
    }

    private func notify(_ event: ChatSectionProvidingEvent) {
        observers.removeAll { $0.observer == nil }
        let activeObservers = observers
        for observer in activeObservers {
            observer.observer?.invoke(event)
        }
    }

    /// 把 header / toolbar 可见性绑定到会话选择状态（复刻旧版 `ChatView` 语义：
    /// 无选中会话时隐藏 header / toolbar，仅保留正文与输入区）。
    ///
    /// 由集成层在插件全部启动、`ConversationManaging` 最终实例确定后调用一次；
    /// 订阅由本 Provider 持有，随内核生命周期存续。
    public func bindConversationSelection(_ conversations: any ConversationManaging) {
        setHeaderVisible(conversations.selectedConversationID != nil)
        conversationSelectionCancellable = conversations.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self, weak conversations] _ in
                MainActor.assumeIsolated {
                    guard let self, let conversations else { return }
                    self.setHeaderVisible(conversations.selectedConversationID != nil)
                }
            }
    }

    private final class Observer: ChatSectionProvidingObserverHandle {
        private weak var owner: DefaultChatSectionProviding?
        private let callback: (ChatSectionProvidingEvent) -> Void
        private var cancelled = false

        init(owner: DefaultChatSectionProviding, callback: @escaping (ChatSectionProvidingEvent) -> Void) {
            self.owner = owner
            self.callback = callback
        }

        func cancel() {
            guard !cancelled else { return }
            cancelled = true
            owner?.remove(self)
        }

        func invoke(_ event: ChatSectionProvidingEvent) {
            guard !cancelled else { return }
            callback(event)
        }
    }

    private final class WeakObserver {
        weak var observer: Observer?

        init(_ observer: Observer) {
            self.observer = observer
        }
    }

    public func makeChatSectionView() -> AnyView {
        AnyView(ChatSectionHostView(provider: self))
    }
}

/// 聊天分区宿主视图（公开以便宿主复用 / 自定义宿主组合）。
///
/// 结构对应旧版 `Views/Layout/Chat` 目录：
/// - `ChatView` → 本视图（组合入口）
/// - `ChatHeaderView` → `ChatHeaderRow`
/// - `ChatToolbarView` → `ChatToolbarRow`
/// - `ChatSectionContentView` → `ChatStackView` + `ChatBottomFixedView`
/// - `ChatActionBar` → `ChatActionBarView`
///
/// 样式对齐旧版：header / toolbar / action bar 均复用 `AppToolbarContainer` +
/// `AppPanelChromeMetrics`，与旧版高度、内边距、背景、边框、阴影一致。
@MainActor
public struct ChatSectionHostView: View {
    @ObservedObject var provider: DefaultChatSectionProviding

    public init(provider: DefaultChatSectionProviding) {
        self.provider = provider
    }

    private var stackItems: [ChatSectionItem] {
        provider.items.filter {
            $0.placement == .stack && $0.scope.matches(provider.activeContext)
        }
    }

    private var bottomItems: [ChatSectionItem] {
        provider.items.filter {
            $0.placement == .bottomFixed && $0.scope.matches(provider.activeContext)
        }
    }

    private func bars(_ placement: ChatSectionBarPlacement) -> [ChatSectionBarItem] {
        provider.barItems.filter {
            $0.placement == placement && $0.scope.matches(provider.activeContext)
        }
    }

    private var orderedRootWrappers: [ChatSectionRootWrapper] {
        provider.rootWrappers
            .filter { $0.scope.matches(provider.activeContext) }
            .sorted { $0.order == $1.order ? $0.id < $1.id : $0.order < $1.order }
    }

    public var body: some View {
        wrappedContent
    }

    /// 根包装器链式叠加：order 升序，先注册的先包（最小 order 在最外层）。
    private var wrappedContent: AnyView {
        var result = AnyView(baseContent)
        for wrapper in orderedRootWrappers {
            result = wrapper.wrap(result)
        }
        return result
    }

    private var baseContent: some View {
        Group {
            if provider.isVisible {
                VStack(spacing: 0) {
                    if provider.isContextActive, provider.isHeaderVisible {
                        ChatHeaderRow(items: bars(.header))
                        ChatToolbarRow(
                            leading: bars(.toolbarLeading),
                            trailing: bars(.toolbarTrailing)
                        )
                    }

                    ChatStackView(items: stackItems)
                        .frame(maxHeight: .infinity)

                    // 复刻旧版 ChatSectionContentView：stack 与 bottomFixed 之间的分隔线，
                    // 仅当两者都非空且 stack 最后一项声明显示分隔线时绘制。
                    if !stackItems.isEmpty, !bottomItems.isEmpty,
                       stackItems.last?.showsTrailingDivider ?? true {
                        AppDivider()
                    }

                    ChatBottomFixedView(items: bottomItems)

                    ChatActionBarView(
                        leading: bars(.actionLeading),
                        trailing: bars(.actionTrailing)
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

/// 正文 stack 区：`fillsRemainingHeight` 的项占满剩余高度，未声明时第一项兜底。
@MainActor
private struct ChatStackView: View {
    let items: [ChatSectionItem]

    var body: some View {
        let hasPrimary = items.contains { $0.fillsRemainingHeight }
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                let isPrimary = item.fillsRemainingHeight || (!hasPrimary && index == 0)
                item.makeView()
                    .frame(maxWidth: .infinity, alignment: .top)
                    .frame(maxHeight: isPrimary ? .infinity : nil, alignment: .top)
                    .layoutPriority(isPrimary ? 1 : 0)

                if index < items.count - 1, item.showsTrailingDivider {
                    AppDivider()
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

/// 底部固定区（输入框等）。
@MainActor
private struct ChatBottomFixedView: View {
    let items: [ChatSectionItem]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                item.makeView()
                    .frame(maxWidth: .infinity, alignment: .bottom)

                if index < items.count - 1, item.showsTrailingDivider {
                    AppDivider()
                }
            }
        }
    }
}

/// header 栏：对应旧版 `ChatHeaderView`（`AppToolbarContainer` height 40、
/// `.panel` 背景、上下 8 / 左右 10 内边距、底部边框）。
@MainActor
private struct ChatHeaderRow: View {
    let items: [ChatSectionBarItem]

    var body: some View {
        AppToolbarContainer(
            height: 40,
            backgroundStyle: .panel,
            padding: EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10)
        ) {
            HStack(spacing: 8) {
                ForEach(items) { $0.makeView() }
                Spacer(minLength: 0)
            }
        }
        .borderBottom()
    }
}

/// toolbar 栏：对应旧版 `ChatToolbarView`（`breadcrumbBarHeight` 高度、
/// `.panel` 背景、breadcrumb 内边距、底部边框 + `shadowMd`）。
@MainActor
private struct ChatToolbarRow: View {
    let leading: [ChatSectionBarItem]
    let trailing: [ChatSectionBarItem]

    var body: some View {
        AppToolbarContainer(
            height: AppPanelChromeMetrics.breadcrumbBarHeight,
            backgroundStyle: .panel,
            padding: EdgeInsets(
                top: AppPanelChromeMetrics.breadcrumbVerticalPadding,
                leading: AppPanelChromeMetrics.breadcrumbHorizontalPadding,
                bottom: AppPanelChromeMetrics.breadcrumbVerticalPadding,
                trailing: AppPanelChromeMetrics.breadcrumbHorizontalPadding
            )
        ) {
            HStack(alignment: .center, spacing: 8) {
                ForEach(leading) { $0.makeView() }
                Spacer(minLength: 0)
                HStack(spacing: 8) {
                    ForEach(trailing) { $0.makeView() }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: AppPanelChromeMetrics.breadcrumbContentHeight, alignment: .center)
        }
        .borderBottom()
        .shadowMd()
    }
}

/// action bar：对应旧版 `ChatActionBar`（`actionBarHeight` 高度、`.panel` 背景、
/// actionBar 内边距、`actionBarItemSpacing` 间距、顶部边框）。
@MainActor
private struct ChatActionBarView: View {
    let leading: [ChatSectionBarItem]
    let trailing: [ChatSectionBarItem]

    var body: some View {
        Group {
            if !leading.isEmpty || !trailing.isEmpty {
                AppToolbarContainer(
                    height: AppPanelChromeMetrics.actionBarHeight,
                    backgroundStyle: .panel,
                    padding: EdgeInsets(
                        top: AppPanelChromeMetrics.actionBarVerticalPadding,
                        leading: AppPanelChromeMetrics.breadcrumbHorizontalPadding,
                        bottom: AppPanelChromeMetrics.actionBarVerticalPadding,
                        trailing: AppPanelChromeMetrics.breadcrumbHorizontalPadding
                    )
                ) {
                    HStack(spacing: AppPanelChromeMetrics.actionBarItemSpacing) {
                        ForEach(leading) { $0.makeView() }
                        Spacer(minLength: 0)
                        HStack(spacing: AppPanelChromeMetrics.actionBarItemSpacing) {
                            ForEach(trailing) { $0.makeView() }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .borderTop()
            }
        }
    }
}
