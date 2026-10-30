import Foundation
import KitAgentTool
import ProviderConversation
import ProviderMessage
import Testing
@testable import PluginMessageRenderer

@Suite("工具调用组折叠策略")
struct ToolCallGroupCollapsePolicyTests {
    // MARK: - 折叠判定

    @Test("单个工具调用不折叠")
    func singleCallIsNotCollapsed() {
        #expect(!ToolCallGroupCollapsePolicy.shouldCollapse([makeCall(id: "a")], verbosity: .standard))
    }

    @Test("空组不折叠")
    func emptyGroupIsNotCollapsed() {
        #expect(!ToolCallGroupCollapsePolicy.shouldCollapse([], verbosity: .standard))
    }

    @Test("多个已完成的工具调用折叠")
    func multipleCompletedCallsAreCollapsed() {
        let calls = [
            makeCall(id: "a", result: makeResult()),
            makeCall(id: "b", result: makeResult()),
        ]
        #expect(ToolCallGroupCollapsePolicy.shouldCollapse(calls, verbosity: .standard))
    }

    @Test("多个进行中的工具调用折叠")
    func multipleRunningCallsAreCollapsed() {
        let calls = [
            makeCall(id: "a", result: makeResult()),
            makeCall(id: "b"),
        ]
        #expect(ToolCallGroupCollapsePolicy.shouldCollapse(calls, verbosity: .standard))
    }

    // MARK: - 只有 V2 折叠

    @Test("V3（detailed）保持逐条铺开，不折叠")
    func detailedIsNotCollapsed() {
        let calls = [
            makeCall(id: "a", result: makeResult()),
            makeCall(id: "b", result: makeResult()),
        ]
        #expect(!ToolCallGroupCollapsePolicy.shouldCollapse(calls, verbosity: .detailed))
    }

    @Test("V1（brief）保持逐条铺开，不折叠")
    func briefIsNotCollapsed() {
        let calls = [
            makeCall(id: "a", result: makeResult()),
            makeCall(id: "b", result: makeResult()),
        ]
        #expect(!ToolCallGroupCollapsePolicy.shouldCollapse(calls, verbosity: .brief))
    }

    /// brief 在进入渲染层之前被升格为 standard（复用 V2 内容布局）。
    /// 若折叠判定用了升格后的值，V1 会被连坐成 V2 一并折叠——
    /// 这条用例把这个前提钉死，避免后来者改回用升格值。
    @Test("brief 会被升格为 standard，折叠判定必须用原始级别")
    func briefIsUpgradedToStandard() {
        #expect(AssistantMessageView.contentVerbosity(for: .brief) == .standard)
        #expect(AssistantMessageView.contentVerbosity(for: .standard) == .standard)
        #expect(AssistantMessageView.contentVerbosity(for: .detailed) == .detailed)
    }

    // MARK: - 交互挂起必须强制展开

    @Test("等待授权的调用不折叠")
    func pendingAuthorizationIsNotCollapsed() {
        let calls = [
            makeCall(id: "a", result: makeResult()),
            makeCall(
                id: "b",
                result: nil,
                authorizationState: ToolCallAuthorizationState.pendingAuthorization.rawValue
            ),
        ]
        #expect(!ToolCallGroupCollapsePolicy.shouldCollapse(calls, verbosity: .standard))
    }

    @Test("等待用户作答的调用不折叠")
    func awaitingUserResponseIsNotCollapsed() {
        let calls = [
            makeCall(id: "a", result: makeResult()),
            makeCall(id: "b", result: makeResult(awaitingUserResponse: true)),
        ]
        #expect(!ToolCallGroupCollapsePolicy.shouldCollapse(calls, verbosity: .standard))
    }

    @Test("授权状态缺失且结果未出时按等待授权处理")
    func missingAuthorizationStateWithoutResultIsTreatedAsPending() {
        let calls = [
            makeCall(id: "a", result: makeResult()),
            makeCall(id: "b", result: nil, authorizationState: nil),
        ]
        #expect(!ToolCallGroupCollapsePolicy.shouldCollapse(calls, verbosity: .standard))
    }

    @Test("授权状态缺失但已有结果时不算挂起")
    func missingAuthorizationStateWithResultIsNotPending() {
        // 旧数据：已完成却没有写授权终态。此时不应被误判为挂起，
        // 否则这组调用永远折叠不了。
        let calls = [
            makeCall(id: "a", result: makeResult()),
            makeCall(id: "b", result: makeResult(), authorizationState: nil),
        ]
        #expect(ToolCallGroupCollapsePolicy.shouldCollapse(calls, verbosity: .standard))
    }

    @Test("用户已授权的调用不阻止折叠")
    func approvedCallDoesNotBlockCollapsing() {
        let calls = [
            makeCall(id: "a", result: makeResult()),
            makeCall(
                id: "b",
                result: makeResult(),
                authorizationState: ToolCallAuthorizationState.userApproved.rawValue
            ),
        ]
        #expect(ToolCallGroupCollapsePolicy.shouldCollapse(calls, verbosity: .standard))
    }

    @Test("用户已拒绝的调用不阻止折叠")
    func rejectedCallDoesNotBlockCollapsing() {
        let calls = [
            makeCall(id: "a", result: makeResult()),
            makeCall(
                id: "b",
                result: makeResult(),
                authorizationState: ToolCallAuthorizationState.userRejected.rawValue
            ),
        ]
        #expect(ToolCallGroupCollapsePolicy.shouldCollapse(calls, verbosity: .standard))
    }

    // MARK: - 挂起检测

    @Test("挂起检测只看组内是否有交互调用")
    func detectsAwaitingInteraction() {
        #expect(!ToolCallGroupCollapsePolicy.hasAwaitingUserInteraction([makeCall(id: "a")]))
        #expect(
            ToolCallGroupCollapsePolicy.hasAwaitingUserInteraction([
                makeCall(id: "a", result: makeResult(awaitingUserResponse: true))
            ])
        )
    }

    // MARK: - Helpers

    private func makeCall(
        id: String,
        result: MessageToolResult? = nil,
        authorizationState: String? = ToolCallAuthorizationState.autoApproved.rawValue
    ) -> MessageToolCall {
        MessageToolCall(
            id: id,
            name: "read_file",
            arguments: "{}",
            result: result,
            displayDescription: "读取文件",
            authorizationState: authorizationState
        )
    }

    private func makeResult(awaitingUserResponse: Bool = false) -> MessageToolResult {
        MessageToolResult(
            content: "ok",
            duration: 1,
            isError: false,
            awaitingUserResponse: awaitingUserResponse
        )
    }
}
