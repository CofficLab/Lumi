import SwiftUI
import Testing
@testable import ProviderLogo

@MainActor
@Suite("ProviderLogo")
struct ProviderLogoTests {

    // MARK: - Helpers

    private func makeItem(_ id: String, order: Int = 200) -> LogoItem {
        LogoItem(id: id, order: order) { _ in
            Image(systemName: "circle")
        }
    }

    // MARK: - Registration

    @Test("注册 Logo 项后可按优先级查询")
    func registerAndQueryHighestPriority() {
        let logo = DefaultLogoProviding()

        logo.registerLogoItem(makeItem("low", order: 10))
        logo.registerLogoItem(makeItem("high", order: 500))
        logo.registerLogoItem(makeItem("mid", order: 200))

        #expect(logo.allLogoItems.count == 3)
        #expect(logo.highestPriorityLogoItem?.id == "high")
    }

    @Test("同 id 注册覆盖旧项且不重复插入")
    func registerSameIDOverrides() {
        let logo = DefaultLogoProviding()

        logo.registerLogoItem(makeItem("a", order: 100))
        logo.registerLogoItem(makeItem("a", order: 999))

        #expect(logo.allLogoItems.count == 1)
        #expect(logo.highestPriorityLogoItem?.order == 999)
    }

    @Test("注销后优先级查询回退到下一项")
    func unregisterFallsBack() {
        let logo = DefaultLogoProviding()

        logo.registerLogoItem(makeItem("first", order: 500))
        logo.registerLogoItem(makeItem("second", order: 100))

        logo.unregisterLogoItem(id: "first")

        #expect(logo.allLogoItems.count == 1)
        #expect(logo.highestPriorityLogoItem?.id == "second")
    }

    @Test("清空贡献后无 Logo 项")
    func clearAllContributionsEmpties() {
        let logo = DefaultLogoProviding()

        logo.registerLogoItem(makeItem("a"))
        logo.clearAllContributions()

        #expect(logo.allLogoItems.isEmpty)
        #expect(logo.highestPriorityLogoItem == nil)
    }

    // MARK: - Highlighted State

    @Test("高亮状态可设置且可回退")
    func highlightStateRoundTrip() {
        let logo = DefaultLogoProviding()

        #expect(logo.isLogoHighlighted == false)

        logo.setLogoHighlighted(true)
        #expect(logo.isLogoHighlighted == true)

        logo.setLogoHighlighted(false)
        #expect(logo.isLogoHighlighted == false)
    }

    @Test("空 Provider 的最高优先级为 nil")
    func emptyProviderReturnsNil() {
        let logo = DefaultLogoProviding()
        #expect(logo.highestPriorityLogoItem == nil)
    }
}
