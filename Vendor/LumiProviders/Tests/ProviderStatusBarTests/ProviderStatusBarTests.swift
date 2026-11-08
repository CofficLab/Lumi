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

/// 状态栏可见性语义：容器是否应渲染完全由「是否存在贡献项」决定。
///
/// 没有贡献项时整条状态栏不渲染；有贡献项时（即使其内容当前渲染为空）仍视为存在贡献，
/// 以避免容器通过测量渲染内容推断可见性。
@Suite("StatusBar 可见性语义")
@MainActor
struct StatusBarVisibilityTests {
    private func item(
        _ id: String,
        content: @escaping () -> AnyView = { AnyView(Text("item")) }
    ) -> StatusBarItem {
        StatusBarItem(id: id, title: id) { content() }
    }

    @Test("没有任何贡献时状态栏不可见")
    func hiddenWithoutItems() {
        let provider = DefaultStatusBarProviding()

        #expect(provider.hasVisibleStatusBarItems == false)
    }

    @Test("存在贡献时状态栏可见")
    func visibleWithItems() {
        let provider = DefaultStatusBarProviding()
        provider.addStatusBarItems([item("git")])

        #expect(provider.hasVisibleStatusBarItems == true)
    }

    @Test("动态撤回全部贡献后状态栏重新隐藏")
    func hidesAfterRemovingAllItems() {
        let provider = DefaultStatusBarProviding()
        provider.addStatusBarItems([item("git"), item("branch")])

        provider.removeStatusBarItems(ids: ["git", "branch"])

        #expect(provider.hasVisibleStatusBarItems == false)
    }

    @Test("重新出现贡献时状态栏恢复可见")
    func becomesVisibleAgainAfterReadding() {
        let provider = DefaultStatusBarProviding()
        provider.addStatusBarItems([item("git")])
        provider.removeStatusBarItems(ids: ["git"])

        provider.addStatusBarItems([item("git")])

        #expect(provider.hasVisibleStatusBarItems == true)
    }

    @Test("贡献存在但内容渲染为空时仍视为存在贡献")
    func emptyContentStillCountsAsContribution() {
        let provider = DefaultStatusBarProviding()
        provider.addStatusBarItems([
            item("placeholder", content: { AnyView(EmptyView()) }),
        ])

        // 语义明确：空内容不等于零贡献，由插件的注册/撤回决定容器可见性。
        #expect(provider.hasVisibleStatusBarItems == true)
    }

    @Test("存在类型同样遵循可见性语义")
    func existentialTypeFollowsVisibilitySemantics() {
        let provider: any StatusBarProviding = DefaultStatusBarProviding()
        #expect(provider.hasVisibleStatusBarItems == false)

        provider.addStatusBarItems([item("git")])

        #expect(provider.hasVisibleStatusBarItems == true)
    }
}

#if os(macOS)
/// 渲染尺寸验证：无贡献时容器必须完全不占高度，有贡献时保持原有 28pt 布局。
@Suite("StatusBar 渲染尺寸")
@MainActor
struct StatusBarRenderSizeTests {
    private func renderedHeight(provider: DefaultStatusBarProviding) -> CGFloat {
        var renderedSize: CGSize = .zero
        let renderer = ImageRenderer(content: provider.makeStatusBarView())
        renderer.proposedSize = ProposedViewSize(width: 900, height: nil)
        renderer.render { size, _ in
            renderedSize = size
        }
        return renderedSize.height
    }

    @Test("无贡献时状态栏渲染高度为 0")
    func emptyStatusBarTakesNoSpace() {
        let provider = DefaultStatusBarProviding()

        #expect(renderedHeight(provider: provider) == 0)
    }

    @Test("有贡献时状态栏保持 28pt 高度")
    func contributedStatusBarKeepsHeight() {
        let provider = DefaultStatusBarProviding()
        provider.addStatusBarItems([
            StatusBarItem(id: "git", title: "Git") { Text("Git") },
        ])

        #expect(renderedHeight(provider: provider) == 28)
    }

    @Test("撤回全部贡献后渲染高度回到 0")
    func heightReturnsToZeroAfterRemove() {
        let provider = DefaultStatusBarProviding()
        provider.addStatusBarItems([
            StatusBarItem(id: "git", title: "Git") { Text("Git") },
        ])
        provider.removeStatusBarItems(ids: ["git"])

        #expect(renderedHeight(provider: provider) == 0)
    }
}
#endif
