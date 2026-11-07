import SwiftUI
import Testing
@testable import ProviderContentView

/// `DefaultContentViewProviding` 的 entries 状态机。
///
/// `DefaultContentViewProviding` 同时维护两条内容通道：
/// - `entries`：旧版多内容区 API（`addContentView` / `removeContentView`），按 `order` 排序；
/// - `contentView`：单内容通道（`setContentView`）。
///
/// 二者互斥：写 `entries` 会清空 `contentView`，反之亦然。事件节流规则是
/// 「无实际变化不发事件」，避免 SwiftUI 无谓刷新。
@Suite("ContentView entries 状态机")
@MainActor
struct ContentViewEntriesTests {

    private func view(_ id: String) -> AnyView { AnyView(Text(id)) }

    private func tab(
        _ id: String,
        order: Int
    ) -> ContentTabItem {
        ContentTabItem(id: id, title: id, order: order, content: view(id))
    }

    // MARK: - addContentView

    @Test("addContentView 按 order 升序插入")
    func addSortsByOrder() {
        let provider = DefaultContentViewProviding()

        provider.addContentView(view("c"), id: "c", order: 300)
        provider.addContentView(view("a"), id: "a", order: 100)
        provider.addContentView(view("b"), id: "b", order: 200)

        #expect(provider.renderedIDs == ["a", "b", "c"])
    }

    @Test("同 id 重复 addContentView 替换而非追加")
    func addReplacesSameID() {
        let provider = DefaultContentViewProviding()
        provider.addContentView(view("a"), id: "a", order: 100)

        provider.addContentView(view("a2"), id: "a", order: 500)

        #expect(provider.renderedIDs == ["a"])
        #expect(provider.entryOrders == [500])
    }

    @Test("同 id 替换后按新 order 重新排序")
    func replaceRepositionsItem() {
        let provider = DefaultContentViewProviding()
        provider.addContentView(view("a"), id: "a", order: 100)
        provider.addContentView(view("b"), id: "b", order: 200)

        // 把 a 移到末尾
        provider.addContentView(view("a"), id: "a", order: 900)

        #expect(provider.renderedIDs == ["b", "a"])
    }

    @Test("order 相同时保持注册顺序")
    func addKeepsStableOrderForEqualOrder() {
        let provider = DefaultContentViewProviding()

        provider.addContentView(view("first"), id: "first", order: 100)
        provider.addContentView(view("second"), id: "second", order: 100)

        #expect(provider.renderedIDs == ["first", "second"])
    }

    @Test("addContentView 会清空单内容通道")
    func addClearsSingleContentChannel() {
        let provider = DefaultContentViewProviding()
        provider.setContentView(view("single"))

        provider.addContentView(view("multi"), id: "multi", order: 100)

        #expect(provider.currentRenderedContent != nil)
        #expect(provider.singleContentIsNil)
    }

    // MARK: - removeContentView

    @Test("removeContentView 移除指定 id")
    func removesByID() {
        let provider = DefaultContentViewProviding()
        provider.addContentView(view("a"), id: "a", order: 100)
        provider.addContentView(view("b"), id: "b", order: 200)

        provider.removeContentView(id: "a")

        #expect(provider.renderedIDs == ["b"])
    }

    @Test("移除不存在的 id 不发事件")
    func removingUnknownIDDoesNotNotify() {
        let provider = DefaultContentViewProviding()
        provider.addContentView(view("a"), id: "a", order: 100)
        var events = 0
        let handle = provider.addContentViewObserver { _ in events += 1 }

        provider.removeContentView(id: "missing")

        #expect(events == 0)
        #expect(provider.renderedIDs == ["a"])
        handle.cancel()
    }

    @Test("移除最后一项后回退到空内容")
    func removingLastEntryEmptiesContent() {
        let provider = DefaultContentViewProviding()
        provider.addContentView(view("a"), id: "a", order: 100)

        provider.removeContentView(id: "a")

        #expect(provider.currentRenderedContent == nil)
    }

    // MARK: - removeAllContentView

    @Test("removeAllContentView 清空 entries 与单内容通道")
    func removeAllClearsBothChannels() {
        let provider = DefaultContentViewProviding()
        provider.addContentView(view("a"), id: "a", order: 100)
        provider.addContentView(view("b"), id: "b", order: 200)

        provider.removeAllContentView()

        #expect(provider.currentRenderedContent == nil)
        #expect(provider.singleContentIsNil)
    }

    @Test("空状态下 removeAllContentView 不发事件")
    func removeAllOnEmptyDoesNotNotify() {
        let provider = DefaultContentViewProviding()
        var events = 0
        let handle = provider.addContentViewObserver { _ in events += 1 }

        provider.removeAllContentView()

        #expect(events == 0)
        handle.cancel()
    }

    @Test("先 add 后 removeAll 发一次事件")
    func removeAllAfterAddNotifiesOnce() {
        let provider = DefaultContentViewProviding()
        provider.addContentView(view("a"), id: "a", order: 100)
        var events = 0
        let handle = provider.addContentViewObserver { _ in events += 1 }

        provider.removeAllContentView()

        #expect(events == 1)
        handle.cancel()
    }

    // MARK: - setContentView

    @Test("setContentView 清空 entries 通道")
    func setContentClearsEntries() {
        let provider = DefaultContentViewProviding()
        provider.addContentView(view("a"), id: "a", order: 100)

        provider.setContentView(view("single"))

        #expect(provider.currentRenderedContent != nil)
        #expect(provider.singleContentIsNil == false)
    }

    // MARK: - setTabs

    @Test("setTabs 按 order 排序并写入 tabs 属性")
    func setTabsSortsAndStores() {
        let provider = DefaultContentViewProviding()

        provider.setTabs([tab("c", order: 300), tab("a", order: 100)])

        #expect(provider.tabs.map(\.id) == ["a", "c"])
        #expect(provider.renderedIDs == ["a", "c"])
    }

    @Test("setTabs 会替换已有 entries 而非追加")
    func setTabsReplacesPreviousEntries() {
        let provider = DefaultContentViewProviding()
        provider.addContentView(view("legacy"), id: "legacy", order: 50)

        provider.setTabs([tab("new", order: 100)])

        #expect(provider.renderedIDs == ["new"])
    }

    @Test("setTabs 清空单内容通道")
    func setTabsClearsSingleChannel() {
        let provider = DefaultContentViewProviding()
        provider.setContentView(view("single"))

        provider.setTabs([tab("a", order: 100)])

        #expect(provider.singleContentIsNil)
        #expect(provider.renderedIDs == ["a"])
    }

    @Test("setTabs 传空数组清空一切")
    func setEmptyTabsClearsEverything() {
        let provider = DefaultContentViewProviding()
        provider.addContentView(view("a"), id: "a", order: 100)

        provider.setTabs([])

        #expect(provider.tabs.isEmpty)
        #expect(provider.currentRenderedContent == nil)
    }

    // MARK: - Demo Mode

    @Test("setDemoMode 切换状态")
    func togglesDemoMode() {
        let provider = DefaultContentViewProviding()
        #expect(provider.isDemoMode == false)

        provider.setDemoMode(true)
        #expect(provider.isDemoMode == true)

        provider.setDemoMode(false)
        #expect(provider.isDemoMode == false)
    }

    // MARK: - Observers

    @Test("多个观察者都收到 contentChanged")
    func notifiesAllObservers() {
        let provider = DefaultContentViewProviding()
        var first = 0
        var second = 0
        let a = provider.addContentViewObserver { _ in first += 1 }
        let b = provider.addContentViewObserver { _ in second += 1 }

        provider.addContentView(view("x"), id: "x", order: 100)

        #expect(first == 1)
        #expect(second == 1)
        a.cancel()
        b.cancel()
    }

    @Test("取消后不再收到事件，且取消幂等")
    func cancelStopsNotifications() {
        let provider = DefaultContentViewProviding()
        var count = 0
        let handle = provider.addContentViewObserver { _ in count += 1 }

        provider.addContentView(view("x"), id: "x", order: 100)
        #expect(count == 1)

        handle.cancel()
        handle.cancel()

        provider.addContentView(view("y"), id: "y", order: 200)
        #expect(count == 1)
    }
}

/// `ContentViewProviding` 协议扩展的兜底实现。
///
/// 宿主可能提供只实现最小契约（`setContentView` / `makeContentView`）的
/// 轻量 provider，此时多内容区 API 必须回落到单内容通道而不是崩掉。
@Suite("ContentViewProviding 协议兜底")
@MainActor
struct ContentViewProvidingFallbackTests {

    /// 只实现最小契约的自定义 provider。
    private final class MinimalProvider: ContentViewProviding {
        private(set) var content: AnyView?
        private(set) var setContentViewCallCount = 0

        func setContentView(_ view: AnyView?) {
            setContentViewCallCount += 1
            content = view
        }

        func makeContentView() -> AnyView {
            AnyView(content ?? AnyView(Text("empty")))
        }
    }

    @Test("默认 tabs 为空、isDemoMode 为 false")
    func providesDefaultTabState() {
        let provider = MinimalProvider()

        #expect(provider.tabs.isEmpty)
        #expect(provider.isDemoMode == false)
    }

    @Test("setDemoMode 默认实现为空操作")
    func setDemoModeIsNoop() {
        let provider = MinimalProvider()

        provider.setDemoMode(true)

        #expect(provider.isDemoMode == false)
    }

    @Test("addContentView 兜底为 setContentView")
    func addFallsBackToSetContentView() {
        let provider = MinimalProvider()

        provider.addContentView(AnyView(Text("multi")), id: "multi", order: 100)

        #expect(provider.setContentViewCallCount == 1)
        #expect(provider.content != nil)
    }

    @Test("removeContentView 兜底为 setContentView(nil)")
    func removeFallsBackToSetNil() {
        let provider = MinimalProvider()
        provider.setContentView(AnyView(Text("x")))

        provider.removeContentView(id: "anything")

        #expect(provider.content == nil)
    }

    @Test("removeAllContentView 兜底为 setContentView(nil)")
    func removeAllFallsBackToSetNil() {
        let provider = MinimalProvider()
        provider.setContentView(AnyView(Text("x")))

        provider.removeAllContentView()

        #expect(provider.content == nil)
    }

    @Test("默认 setTabs 按 order 排序后逐个 addContentView")
    func defaultSetTabsSortsThenAdds() {
        final class Spy: ContentViewProviding {
            var added: [(String, Int)] = []
            func setContentView(_ view: AnyView?) {}
            func addContentView(_ view: AnyView, id: String, order: Int) {
                added.append((id, order))
            }
            func makeContentView() -> AnyView { AnyView(EmptyView()) }
        }
        let spy = Spy()

        spy.setTabs([
            ContentTabItem(id: "c", title: "C", order: 300, content: AnyView(Text("C"))),
            ContentTabItem(id: "a", title: "A", order: 100, content: AnyView(Text("A"))),
            ContentTabItem(id: "b", title: "B", order: 200, content: AnyView(Text("B"))),
        ])

        #expect(spy.added.map(\.0) == ["a", "b", "c"])
        #expect(spy.added.map(\.1) == [100, 200, 300])
    }

    @Test("默认 addContentViewObserver 返回可安全取消的空句柄")
    func defaultObserverHandleIsSafeToCancel() {
        let provider = MinimalProvider()

        let handle = provider.addContentViewObserver { _ in
            Issue.record("默认实现不应触发回调")
        }
        handle.cancel()
        handle.cancel()
    }
}
