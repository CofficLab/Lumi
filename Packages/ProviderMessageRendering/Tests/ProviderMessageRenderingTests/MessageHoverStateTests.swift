import Foundation
import Testing
@testable import ProviderMessageRendering

/// `MessageHoverState` 的 hover 防抖契约测试。
///
/// 关键约束：
/// - **进入**有防抖（150ms）：滚动时光标下的行快速进出，
///   立即物化操作按钮会造成 hover 风暴；
/// - **离开**立即隐藏：标准菜单式交互，离开就该消失。
@Suite("MessageHoverState hover 防抖")
@MainActor
struct MessageHoverStateTests {

    @Test("初始状态不是 hover")
    func startsNotHovered() {
        let state = MessageHoverState()
        #expect(state.isHovered == false)
    }

    @Test("进入延迟是 150ms")
    func enterDelayIs150ms() {
        #expect(MessageHoverState.enterDelay == 0.15)
    }

    @Test("进入后经过防抖窗口才变为 hover")
    func becomesHoveredAfterDelay() async throws {
        let state = MessageHoverState()

        state.setHovering(true)

        // 防抖窗口内不得立刻变成 hover。
        #expect(state.isHovered == false)

        try await Task.sleep(for: .milliseconds(250))

        #expect(state.isHovered == true)
    }

    @Test("离开立即隐藏，不等防抖窗口")
    func leavingHidesImmediately() async throws {
        let state = MessageHoverState()

        state.setHovering(true)
        try await Task.sleep(for: .milliseconds(250))
        #expect(state.isHovered == true)

        state.setHovering(false)

        // 离开是**立即**的：不等 150ms。
        #expect(state.isHovered == false)
    }

    @Test("进入后在窗口内离开，不会变成 hover")
    func leavingDuringDebounceNeverHovers() async throws {
        let state = MessageHoverState()

        state.setHovering(true)
        try await Task.sleep(for: .milliseconds(50))
        state.setHovering(false)

        try await Task.sleep(for: .milliseconds(250))

        #expect(state.isHovered == false)
    }

    @Test("反复进入只会有一次最终 hover")
    func repeatedEnteringSettlesToHovered() async throws {
        let state = MessageHoverState()

        // 模拟滚动时快速掠过：进入 → 离开 → 进入。
        state.setHovering(true)
        state.setHovering(false)
        state.setHovering(true)

        try await Task.sleep(for: .milliseconds(250))

        #expect(state.isHovered == true)
    }
}
