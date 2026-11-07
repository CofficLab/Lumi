import SwiftUI
import Testing
@testable import ProviderStatusBar

@Suite("ProviderStatusBar")
@MainActor
struct ProviderStatusBarTests {
    @Test("状态栏保留所有插件项，场景可见性由插件管理")
    func keepsAllStatusBarItems() {
        let implementation = DefaultStatusBarProviding()
        let provider: any StatusBarProviding = implementation
        provider.registerStatusBarItems([
            StatusBarItem(id: "git", title: "Git") { Text("Git") },
            StatusBarItem(id: "banner", title: "Banner") { Text("Banner") },
        ])

        #expect(implementation.visibleStatusBarItems.map(\.id) == ["git", "banner"])
    }
}

/// `StatusBarProviding` 协议扩展的合并 / 排序 / 撤回语义。
///
/// 这是插件贡献状态栏项的真实业务逻辑：多个插件各自 `addStatusBarItems`，
/// 必须保证「按 order 稳定排序 + 同 id 去重保留先注册者 + 可按 id 撤回」。
@Suite("StatusBarProviding 合并语义")
@MainActor
struct StatusBarProvidingMergeTests {
    private func item(
        _ id: String,
        order: Int = 200,
        placement: StatusBarPlacement = .trailing
    ) -> StatusBarItem {
        StatusBarItem(id: id, title: id, placement: placement, order: order) {
            Text(id)
        }
    }

    @Test("addStatusBarItems 保留已有项并追加新项")
    func appendsNewItems() {
        let provider = DefaultStatusBarProviding()
        provider.registerStatusBarItems([item("a")])

        provider.addStatusBarItems([item("b")])

        #expect(provider.statusBarItems.map(\.id) == ["a", "b"])
    }

    @Test("addStatusBarItems 按 order 升序排列")
    func sortsByOrder() {
        let provider = DefaultStatusBarProviding()

        provider.addStatusBarItems([item("c", order: 300)])
        provider.addStatusBarItems([item("a", order: 100)])
        provider.addStatusBarItems([item("b", order: 200)])

        #expect(provider.statusBarItems.map(\.id) == ["a", "b", "c"])
    }

    @Test("order 相同时保持注册顺序（稳定排序）")
    func keepsStableOrderForEqualOrder() {
        let provider = DefaultStatusBarProviding()

        provider.addStatusBarItems([item("first", order: 100)])
        provider.addStatusBarItems([item("second", order: 100)])
        provider.addStatusBarItems([item("third", order: 100)])

        #expect(provider.statusBarItems.map(\.id) == ["first", "second", "third"])
    }

    @Test("同 id 去重且保留先注册者的 order")
    func dedupesByIDKeepingFirstRegistration() {
        let provider = DefaultStatusBarProviding()
        provider.registerStatusBarItems([item("git", order: 100)])

        // 重复注入同 id 但更高 order：应被忽略，不覆盖先注册者。
        provider.addStatusBarItems([item("git", order: 999)])

        #expect(provider.statusBarItems.count == 1)
        #expect(provider.statusBarItems.first?.id == "git")
        #expect(provider.statusBarItems.first?.order == 100)
    }

    @Test("一次注入内部含重复 id 时也只保留首个")
    func dedupesWithinSingleBatch() {
        let provider = DefaultStatusBarProviding()

        provider.addStatusBarItems([
            item("dup", order: 100),
            item("dup", order: 500),
            item("other", order: 200),
        ])

        #expect(provider.statusBarItems.map(\.id) == ["dup", "other"])
        #expect(provider.statusBarItems.first?.order == 100)
    }

    @Test("removeStatusBarItems 按 id 撤回指定贡献")
    func removesItemsByID() {
        let provider = DefaultStatusBarProviding()
        provider.addStatusBarItems([item("a"), item("b"), item("c")])

        provider.removeStatusBarItems(ids: ["a", "c"])

        #expect(provider.statusBarItems.map(\.id) == ["b"])
    }

    @Test("移除不存在的 id 不影响现有项")
    func removingUnknownIDIsNoop() {
        let provider = DefaultStatusBarProviding()
        provider.addStatusBarItems([item("a")])

        provider.removeStatusBarItems(ids: ["missing"])

        #expect(provider.statusBarItems.map(\.id) == ["a"])
    }

    @Test("移除全部项后状态栏为空")
    func removesAllItems() {
        let provider = DefaultStatusBarProviding()
        provider.addStatusBarItems([item("a"), item("b")])

        provider.removeStatusBarItems(ids: ["a", "b"])

        #expect(provider.statusBarItems.isEmpty)
        #expect(provider.visibleStatusBarItems.isEmpty)
    }

    @Test("扩展方法通过 any StatusBarProviding 存在类型同样生效")
    func worksThroughExistentialType() {
        let provider: any StatusBarProviding = DefaultStatusBarProviding()

        provider.addStatusBarItems([item("b", order: 200)])
        provider.addStatusBarItems([item("a", order: 100)])

        #expect(provider.visibleStatusBarItems.map(\.id) == ["a", "b"])
    }
}
