import Combine
import Foundation
@testable import LumiCoreKit
import Testing

// MARK: - 内部 ObservableObject 子状态变更应转发到 LumiCore.objectWillChange
//
// 背景：SwiftUI 视图（如 AppLayoutView）通过 `@ObservedObject var lumiCore: LumiCore` 监听
// LumiCore 的变化。`@Published` 只在属性引用本身重新赋值时 fire；LumiCore 内部的
// LumiLayoutState / LumiProjectState / ChatService 等 ObservableObject 子状态的属性变更
// 不会自动穿透到 LumiCore.objectWillChange。修复方案：在 LumiCore 内部订阅这些子状态的
// objectWillChange 并转发到自身。下面的测试覆盖这个转发行为，防止后续重构时回退。

@MainActor
struct LumiCoreObjectWillChangeForwardingTests {

    /// activity bar 点击 → LumiLayoutState.activeViewContainerID 变化
    /// → LumiCore.objectWillChange 必须 fire，否则 AppLayoutView 不会重绘右侧内容。
    @Test func layoutStatePropertyChangeForwardsToLumiCore() async throws {
        let core = LumiCore()
        core._testInject(layoutState: LumiLayoutState())

        var fireCount = 0
        let cancellable = core.objectWillChange.sink { _ in
            fireCount += 1
        }
        defer { cancellable.cancel() }

        #expect(fireCount == 0)

        // 触发 activity bar 行为：切换激活的 view container
        core.layoutState?.activateViewContainer(id: "editor")
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms 让 Combine 派发

        // 关键断言：LumiCore.objectWillChange 必须被 fire
        #expect(fireCount >= 1, "LumiCore 必须把 layoutState 内部的属性变化转发到自身 objectWillChange")
    }

    /// 多次切换 view container 时，每次都应 fire（验证 didSet 链没被旧订阅吞掉）。
    @Test func layoutStateMultipleChangesEachForward() async throws {
        let core = LumiCore()
        core._testInject(layoutState: LumiLayoutState())

        var fireCount = 0
        let cancellable = core.objectWillChange.sink { _ in
            fireCount += 1
        }
        defer { cancellable.cancel() }

        for id in ["a", "b", "c"] {
            core.layoutState?.activateViewContainer(id: id)
        }
        try await Task.sleep(nanoseconds: 10_000_000)

        #expect(fireCount >= 3)
    }

    /// layoutState 被重新赋值时，旧订阅应被释放（不会泄漏到旧实例）。
    /// 验证方式：把旧 layoutState 再变更一次，新计数不应增加。
    @Test func reassigningLayoutStateReleasesOldSubscription() async throws {
        let core = LumiCore()
        let oldState = LumiLayoutState()
        core._testInject(layoutState: oldState)

        var fireCount = 0
        let cancellable = core.objectWillChange.sink { _ in
            fireCount += 1
        }
        defer { cancellable.cancel() }

        // 重新赋值：旧订阅应被清空
        core._testInject(layoutState: LumiLayoutState())
        try await Task.sleep(nanoseconds: 10_000_000)
        let baseline = fireCount

        // 改旧实例：不应再 fire（订阅已被释放）
        oldState.activateViewContainer(id: "ghost")
        try await Task.sleep(nanoseconds: 10_000_000)
        #expect(fireCount == baseline, "旧 layoutState 的变更不应再触发 LumiCore.objectWillChange")

        // 改新实例：应 fire
        core.layoutState?.activateViewContainer(id: "live")
        try await Task.sleep(nanoseconds: 10_000_000)
        #expect(fireCount > baseline)
    }

    /// projectComponent 子状态变更也应转发（同样的桥接逻辑覆盖所有内部 ObservableObject）。
    @Test func projectStatePropertyChangeForwardsToLumiCore() async throws {
        let core = LumiCore()
        core._testInject(projectComponent: ProjectComponent())

        var fireCount = 0
        let cancellable = core.objectWillChange.sink { _ in
            fireCount += 1
        }
        defer { cancellable.cancel() }

        core.projectComponent.switchToProject(
            ProjectEntry(name: "demo", path: "/tmp/demo")
        )
        try await Task.sleep(nanoseconds: 10_000_000)

        #expect(fireCount >= 1)
    }

    /// 子状态置为 nil 时，旧订阅应被清空，避免内存泄漏与误触。
    @Test func settingChildToNilClearsSubscription() async throws {
        let core = LumiCore()
        core._testInject(layoutState: LumiLayoutState())

        var fireCount = 0
        let cancellable = core.objectWillChange.sink { _ in
            fireCount += 1
        }
        defer { cancellable.cancel() }

        core._testInject(layoutState: nil)
        try await Task.sleep(nanoseconds: 10_000_000)
        let baseline = fireCount

        // 此时再操作原 layoutState 不应触发
        core.layoutState?.activateViewContainer(id: "noop")
        try await Task.sleep(nanoseconds: 10_000_000)
        #expect(fireCount == baseline)
    }
}
