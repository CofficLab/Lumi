import Foundation
import KitAgentTool
import Testing
@testable import ComputerUsePlugin

/// 复现：**A3 对话中 Computer Use 授权卡片不出现，回合永久挂起。**
///
/// ## 现象
///
/// A3（完全授权）对话里，Agent 操作未授权应用（如 App Store）时，
/// 工具返回 `awaitingUserResponse = true` 的挂起结果，回合挂起、
/// 输入区显示「等待你的输入…」，但**界面上没有任何可点击的授权卡片**。
/// 用户既看不到卡片也无法推进，对话永久停住。
///
/// ## 根因
///
/// 授权卡片由 `ComputerUseAuthorizationRowRenderer.canRender` 判定，
/// 条件之一是 `toolCall.authorizationState == .pendingAuthorization`。
///
/// 但 A3 对话下，LLM 响应落库阶段已把授权状态写成 `autoApproved`
/// （`ToolManager.authorizationDecision` 的 `.autonomous` 分支）。
/// 工具在执行阶段挂起时，落库路径没有回写该状态，于是 `autoApproved`
/// 被保留。渲染器因此拒绝接管，UI 退化成一条只显示原始 JSON 的工具行。
///
/// ## 修复方向
///
/// 两个可选方向，本组用例把它们都表达为**不变量**，使修复方式不影响断言：
///
/// 1. 落库侧回落：工具挂起时把 `authorizationState` 写回
///    `pendingAuthorization`（见 `PluginAgentLoop` 的
///    `SuspendedToolAuthorizationStateTests`）；
/// 2. 渲染侧放宽：`canRender` 改为以「结果确实在等用户回答」为准，
///    不再强依赖 `pendingAuthorization`。
///
/// 无论走哪条，用户可见的结果都必须一致：**挂起中的 Computer Use
/// 授权请求一定要画出卡片**，否则回合会等一个永远不会到来的回答。
///
/// - Note: 这些用例**现在应当失败**。它们是缺陷的复现，不是对现状的认可。
@Suite("Computer Use 授权卡片的渲染条件")
struct ComputerUseAuthorizationCardVisibilityTests {

    private func makeStore() -> (store: ComputerUseAuthorizationStore, directory: URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ComputerUseVisibility-\(UUID().uuidString)", isDirectory: true)
        return (ComputerUseAuthorizationStore(dataDirectory: directory), directory)
    }

    /// 挂起中的 Computer Use 授权请求必须画出卡片。
    ///
    /// 授权状态是 `autoApproved`（A3 场景的落库实况）时同样必须画出——
    /// 这正是线上那条对话的表现：回合已挂起，界面却没有卡片。
    @Test("A3 自动同意状态下，挂起的授权请求仍必须渲染卡片")
    func suspendedRequestRendersCardEvenWhenAutoApproved() throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let coordinator = ComputerUseAuthorizationCoordinator(authorization: store)
        let renderer = ComputerUseAuthorizationRowRenderer(coordinator: coordinator)

        var suspended = ToolCall(
            id: "call-a3",
            name: "accessibility_observe",
            arguments: #"{"application":"App Store"}"#,
            result: coordinator.pendingResult(
                applicationName: "App Store",
                bundleIdentifier: "com.apple.AppStore",
                operation: "accessibility_observe"
            )
        )
        // A3 对话的落库实况：LLM 响应阶段已判定为自动同意。
        suspended.authorizationState = .autoApproved

        #expect(
            renderer.canRender(toolCall: suspended),
            "挂起中的 Computer Use 授权请求必须渲染卡片，否则回合会等一个永远不会到来的回答"
        )
    }

    /// 同一份数据在 `pendingAuthorization` 下必须渲染——
    /// 这是修复后的目标形态，确保修复不会把这条路径改坏。
    @Test("pendingAuthorization 状态下必须渲染卡片")
    func suspendedRequestRendersCardWhenPending() throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let coordinator = ComputerUseAuthorizationCoordinator(authorization: store)
        let renderer = ComputerUseAuthorizationRowRenderer(coordinator: coordinator)

        let suspended = ToolCall(
            id: "call-pending",
            name: "accessibility_observe",
            arguments: #"{"application":"App Store"}"#,
            result: coordinator.pendingResult(
                applicationName: "App Store",
                bundleIdentifier: "com.apple.AppStore",
                operation: "accessibility_observe"
            )
        )

        #expect(renderer.canRender(toolCall: suspended))
    }

    /// 已经完成的调用不得再渲染卡片。
    ///
    /// 修复若选择放宽 `canRender` 条件，最容易引入的回归就是
    /// 「授权决定作出后卡片不消失」。这条锁住该边界。
    @Test("用户已做出决定后不再渲染卡片")
    func decidedRequestDoesNotRenderCard() throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let coordinator = ComputerUseAuthorizationCoordinator(authorization: store)
        let renderer = ComputerUseAuthorizationRowRenderer(coordinator: coordinator)

        var decided = ToolCall(
            id: "call-decided",
            name: "accessibility_observe",
            arguments: #"{"application":"App Store"}"#,
            result: coordinator.pendingResult(
                applicationName: "App Store",
                bundleIdentifier: "com.apple.AppStore",
                operation: "accessibility_observe"
            )
        )
        decided.authorizationState = .userApproved

        #expect(
            !renderer.canRender(toolCall: decided),
            "用户已决定后卡片必须消失，否则界面会一直等一个已经给出的答案"
        )
    }

    /// 正常完成（不等待用户）的调用不得渲染卡片。
    @Test("正常完成的调用不渲染卡片")
    func completedCallDoesNotRenderCard() throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let coordinator = ComputerUseAuthorizationCoordinator(authorization: store)
        let renderer = ComputerUseAuthorizationRowRenderer(coordinator: coordinator)

        var completed = ToolCall(
            id: "call-done",
            name: "accessibility_observe",
            arguments: #"{"application":"App Store"}"#,
            result: ToolCallResult(content: "Observation captured.")
        )
        completed.authorizationState = .autoApproved

        #expect(!renderer.canRender(toolCall: completed))
    }

    /// Computer Use 卡片必须先于通用授权卡片被选中。
    ///
    /// 渲染器按优先级降序取第一个 `canRender` 为真的（见
    /// `ToolCallRenderingProviding.renderer(for:)`）。Computer Use 的优先级
    /// 是 200，高于通用授权卡片的 120——这个顺序不能被破坏，否则
    /// 「允许一次 / 始终允许 / 拒绝」会退化成「允许 / 拒绝」两按钮。
    ///
    /// 这条同时锁住通用渲染器不抢占：通用渲染器只接受
    /// `kind == "permission"` 的载荷，Computer Use 载荷是
    /// `computer_use_authorization`，两者不会互相误判。
    @Test("Computer Use 授权卡片优先于通用授权卡片")
    func computerUseCardOutranksGenericApproval() throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let coordinator = ComputerUseAuthorizationCoordinator(authorization: store)
        let renderer = ComputerUseAuthorizationRowRenderer(coordinator: coordinator)

        #expect(ComputerUseAuthorizationRowRenderer.priority > 120)

        // A3 场景的挂起调用：载荷是 Computer Use 授权请求。
        var suspended = ToolCall(
            id: "call-priority",
            name: "accessibility_observe",
            arguments: #"{"application":"App Store"}"#,
            result: coordinator.pendingResult(
                applicationName: "App Store",
                bundleIdentifier: "com.apple.AppStore",
                operation: "accessibility_observe"
            )
        )
        suspended.authorizationState = .autoApproved

        // 通用授权卡片只接管 `kind == "permission"` 的载荷，
        // 因此不会抢走 Computer Use 的授权请求。
        let genericPayload = #"{"toolCallId":"approval:call-priority","kind":"permission","question":"是否允许执行？","options":["允许","拒绝"],"mode":"yes_no"}"#
        let genericRequest = try #require(
            try? JSONDecoder().decode(
                GenericApprovalPayloadProbe.self,
                from: Data(genericPayload.utf8)
            )
        )
        #expect(genericRequest.kind == "permission")
        #expect(genericRequest.kind != ComputerUseAuthorizationRequest.kind)
        #expect(renderer.canRender(toolCall: suspended))
    }
}

/// 通用授权载荷的最小探针：只用于断言两套载荷的 `kind` 不相同。
private struct GenericApprovalPayloadProbe: Decodable {
    let kind: String
}
