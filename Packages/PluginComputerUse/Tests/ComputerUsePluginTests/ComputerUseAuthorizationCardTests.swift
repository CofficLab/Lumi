import Foundation
import KitAgentTool
import ProviderConversation
import Testing
@testable import ComputerUsePlugin

/// 会话作用域的应用访问授权。
///
/// 授权的边界是**会话**，不是单次操作：一次授权要覆盖整个会话里的
/// 多次访问（观察 → 操作 → 再验证）。
@Suite("Computer Use 会话作用域授权")
struct ComputerUseSessionGrantTests {

    private func makeStore() -> (store: ComputerUseAuthorizationStore, directory: URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ComputerUseSessionGrant-\(UUID().uuidString)", isDirectory: true)
        return (ComputerUseAuthorizationStore(dataDirectory: directory), directory)
    }

    @Test("授权在本会话内持续有效，不被消费")
    func grantIsNotConsumedWithinTheSession() throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let conversationID = UUID()

        store.grantSessionAccess(bundleIdentifier: "com.example.editor", conversationID: conversationID)

        // 观察之后紧接着的操作、再次观察、再次操作——全都必须放行。
        // 授权若在第一次检查时被消费，紧接着的操作就会被自己的授权挡下。
        #expect(store.hasSessionAccess(bundleIdentifier: "com.example.editor", conversationID: conversationID))
        #expect(store.hasSessionAccess(bundleIdentifier: "com.example.editor", conversationID: conversationID))
    }

    @Test("授权不跨会话生效")
    func grantDoesNotLeakAcrossConversations() throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let granted = UUID()
        let other = UUID()

        store.grantSessionAccess(bundleIdentifier: "com.example.editor", conversationID: granted)

        #expect(store.hasSessionAccess(bundleIdentifier: "com.example.editor", conversationID: granted))
        #expect(!store.hasSessionAccess(bundleIdentifier: "com.example.editor", conversationID: other))
    }

    @Test("授权过期后不再有效")
    func expiredGrantIsRejected() throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let conversationID = UUID()

        store.grantSessionAccess(
            bundleIdentifier: "com.example.editor",
            conversationID: conversationID,
            ttl: -1
        )

        #expect(!store.hasSessionAccess(bundleIdentifier: "com.example.editor", conversationID: conversationID))
    }

    @Test("撤销会话授权不影响其他会话")
    func revokingOneSessionKeepsOthers() throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let revoked = UUID()
        let kept = UUID()

        store.grantSessionAccess(bundleIdentifier: "com.example.editor", conversationID: revoked)
        store.grantSessionAccess(bundleIdentifier: "com.example.browser", conversationID: kept)

        store.revokeSessionAccess(conversationID: revoked)

        #expect(!store.hasSessionAccess(bundleIdentifier: "com.example.editor", conversationID: revoked))
        #expect(store.hasSessionAccess(bundleIdentifier: "com.example.browser", conversationID: kept))
    }

    @Test("空 bundle identifier 一律不产生授权")
    func emptyIdentifierIsIgnored() throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let conversationID = UUID()

        store.grantSessionAccess(bundleIdentifier: "", conversationID: conversationID)

        #expect(!store.hasSessionAccess(bundleIdentifier: "", conversationID: conversationID))
    }
}

/// 访问判定的上下文语义。
@Suite("Computer Use 访问上下文")
struct ComputerUseAccessContextTests {

    @Test("A3 会话允许无人值守访问")
    func autonomousAllowsUnattendedAccess() {
        let context = ComputerUseAccessContext(
            conversationID: UUID(),
            automationLevel: .autonomous
        )
        #expect(context.allowsUnattendedAccess)
    }

    @Test("A2 会话不允许无人值守访问")
    func buildDoesNotAllowUnattendedAccess() {
        let context = ComputerUseAccessContext(
            conversationID: UUID(),
            automationLevel: .build
        )
        #expect(!context.allowsUnattendedAccess)
    }

    @Test("A1 会话不允许无人值守访问")
    func chatDoesNotAllowUnattendedAccess() {
        // A1（对话）不执行工具，因此不会走到访问判定；
        // 但万一走到了，按 A2 保守处理而不是静默放行。
        let context = ComputerUseAccessContext(
            conversationID: UUID(),
            automationLevel: .chat
        )
        #expect(!context.allowsUnattendedAccess)
    }

    @Test("A3 会话在共享判定入口上不产生任何授权请求")
    func autonomousSessionNeverRequestsAuthorization() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ComputerUseA3-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ComputerUseAuthorizationStore(dataDirectory: directory)
        let checker = ComputerUseAccessChecker(authorization: store)
        let context = ComputerUseAccessContext(
            conversationID: UUID(),
            automationLevel: .autonomous
        )

        // 四个工具（AX 观察、AX 操作、截图观察、原生操作）共享同一个判定入口。
        // A3 下无论哪个应用都不需要授权，因此不会产生任何授权卡片或挂起。
        for bundleIdentifier in ["com.apple.Safari", "com.apple.Terminal", "com.unknown.app"] {
            #expect(checker.outcome(
                for: bundleIdentifier,
                applicationName: bundleIdentifier,
                context: context
            ) == .allowed)
        }

        // 存储里也没有留下任何会话授权：判定完全由等级驱动。
        #expect(!store.hasSessionAccess(
            bundleIdentifier: "com.apple.Safari",
            conversationID: context.conversationID
        ))
    }
}

/// 授权决策字符串在 UI 与工具之间的往返。
@Suite("Computer Use 授权决策解析")
struct ComputerUseAuthorizationResolverTests {

    @Test("决策标记与枚举一一对应")
    func tokensRoundTrip() {
        for decision in ComputerUseAuthorizationDecision.allCases {
            let token = ComputerUseAuthorizationResolver.token(for: decision)
            #expect(ComputerUseAuthorizationResolver.decision(for: token) == decision)
        }
    }

    @Test("容忍空白、大小写与中英文表述")
    func parsingIsForgiving() {
        #expect(ComputerUseAuthorizationResolver.decision(for: "  ALLOW FOR THIS TASK  ") == .allowForTask)
        #expect(ComputerUseAuthorizationResolver.decision(for: "允许本次任务") == .allowForTask)
        #expect(ComputerUseAuthorizationResolver.decision(for: "Allow for This Task") == .allowForTask)
        #expect(ComputerUseAuthorizationResolver.decision(for: "拒绝") == .deny)
        #expect(ComputerUseAuthorizationResolver.decision(for: "DENY") == .deny)
    }

    @Test("无法识别的答复返回 nil，而不是猜测")
    func unknownAnswerIsNil() {
        #expect(ComputerUseAuthorizationResolver.decision(for: "随便") == nil)
        #expect(ComputerUseAuthorizationResolver.decision(for: "") == nil)
    }

    @Test("只有 deny 不算放行")
    func denyIsTheOnlyRejection() {
        #expect(ComputerUseAuthorizationDecision.allowForTask.isApproved)
        #expect(!ComputerUseAuthorizationDecision.deny.isApproved)
    }

    @Test("卡片只有两个选项")
    func cardHasExactlyTwoOptions() {
        // 「始终允许」已随显式白名单一起下线：白名单要求用户手工维护，
        // 且与会话的自动化等级重复表达同一件事。
        #expect(ComputerUseAuthorizationDecision.allCases == [.allowForTask, .deny])
    }

    @Test("拒绝文案点名目标应用")
    func denialMessageNamesTheApplication() {
        let message = ComputerUseAuthorizationResolver.denialMessage(applicationName: "Safari")

        // 只断言与应用名、与语言无关的契约：拒绝必须点名目标应用，
        // 否则模型无法知道该放弃哪个目标。文案措辞随本地化变化，不做断言。
        #expect(message.contains("Safari"))
    }

    @Test("放行文案说明仅本任务有效")
    func allowMessageStatesScope() {
        let message = ComputerUseAuthorizationResolver.allowForTaskMessage(applicationName: "Safari")

        #expect(message.contains("Safari"))
    }
}

/// 三态判定：放行 / 申请授权 / 禁止。
@Suite("Computer Use 访问判定")
struct ComputerUseAccessCheckerTests {

    private func makeStore() -> (store: ComputerUseAuthorizationStore, directory: URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ComputerUseAccess-\(UUID().uuidString)", isDirectory: true)
        return (ComputerUseAuthorizationStore(dataDirectory: directory), directory)
    }

    private func context(_ level: AutomationLevel, _ conversationID: UUID) -> ComputerUseAccessContext {
        ComputerUseAccessContext(conversationID: conversationID, automationLevel: level)
    }

    @Test("A2 会话中未授权的应用返回需要授权，并带上应用信息")
    func unknownApplicationNeedsAuthorizationInBuildMode() throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        let outcome = ComputerUseAccessChecker(authorization: store)
            .outcome(
                for: "com.example.unknown",
                applicationName: "Unknown",
                context: context(.build, UUID())
            )

        #expect(outcome == .needsAuthorization(
            applicationName: "Unknown",
            bundleIdentifier: "com.example.unknown"
        ))
    }

    @Test("A3 会话中任何应用都直接放行，不打扰用户")
    func autonomousModeAllowsEveryApplication() throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        let outcome = ComputerUseAccessChecker(authorization: store)
            .outcome(
                for: "com.example.unknown",
                applicationName: "Unknown",
                context: context(.autonomous, UUID())
            )

        #expect(outcome == .allowed)
    }

    @Test("A2 会话授权过一次后放行，且授权在会话内不被消费")
    func sessionGrantPassesWithoutBeingConsumed() throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let conversationID = UUID()
        store.grantSessionAccess(bundleIdentifier: "com.example.editor", conversationID: conversationID)

        let checker = ComputerUseAccessChecker(authorization: store)
        let access = context(.build, conversationID)

        // 连续两次判定都必须放行：授权覆盖整个会话，而不是单次操作。
        #expect(checker.outcome(for: "com.example.editor", applicationName: "Editor", context: access) == .allowed)
        #expect(checker.outcome(for: "com.example.editor", applicationName: "Editor", context: access) == .allowed)
    }

    @Test("A2 会话的授权不跨会话")
    func sessionGrantDoesNotLeakAcrossConversations() throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let granted = UUID()
        store.grantSessionAccess(bundleIdentifier: "com.example.editor", conversationID: granted)

        let checker = ComputerUseAccessChecker(authorization: store)
        #expect(checker.outcome(
            for: "com.example.editor",
            applicationName: "Editor",
            context: context(.build, granted)
        ) == .allowed)
        #expect(checker.outcome(
            for: "com.example.editor",
            applicationName: "Editor",
            context: context(.build, UUID())
        ) == .needsAuthorization(
            applicationName: "Editor",
            bundleIdentifier: "com.example.editor"
        ))
    }

    @Test("只读查询不会消耗掉授权")
    func readOnlyCheckDoesNotConsume() throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let conversationID = UUID()
        store.grantSessionAccess(bundleIdentifier: "com.example.editor", conversationID: conversationID)

        let checker = ComputerUseAccessChecker(authorization: store)
        let access = context(.build, conversationID)
        #expect(checker.isAuthorizedWithoutConsuming("com.example.editor", context: access))
        // 查询之后授权必须仍然可用。
        #expect(checker.isAuthorizedWithoutConsuming("com.example.editor", context: access))
        #expect(checker.outcome(for: "com.example.editor", applicationName: "Editor", context: access) == .allowed)
    }

    @Test("A3 会话的只读查询恒为已授权")
    func autonomousReadOnlyCheckIsAlwaysAuthorized() throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        let checker = ComputerUseAccessChecker(authorization: store)
        #expect(checker.isAuthorizedWithoutConsuming(
            "com.example.never-granted",
            context: context(.autonomous, UUID())
        ))
    }

    @Test("空 bundle identifier 视为禁止，不允许申请授权")
    func emptyIdentifierIsForbidden() throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        let outcome = ComputerUseAccessChecker(authorization: store)
            .outcome(
                for: "",
                applicationName: "",
                context: context(.build, UUID())
            )

        guard case .forbidden = outcome else {
            Issue.record("空 bundle identifier 应返回 forbidden，实际：\(outcome)")
            return
        }
    }
}

/// 挂起载荷的编解码与渲染器接管条件。
@Suite("Computer Use 授权挂起载荷")
struct ComputerUseAuthorizationPayloadTests {

    private func makeStore() -> (store: ComputerUseAuthorizationStore, directory: URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ComputerUsePayload-\(UUID().uuidString)", isDirectory: true)
        return (ComputerUseAuthorizationStore(dataDirectory: directory), directory)
    }

    @Test("挂起结果标记为等待用户响应")
    func pendingResultSuspendsTheTurn() throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let coordinator = ComputerUseAuthorizationCoordinator(authorization: store)

        let result = coordinator.pendingResult(
            applicationName: "Safari",
            bundleIdentifier: "com.apple.Safari",
            operation: "computer_observe"
        )

        #expect(result.awaitingUserResponse)
        #expect(!result.isError)
        #expect(result.interactionState == .waiting)
    }

    @Test("挂起载荷可原样解码回授权请求")
    func payloadRoundTrips() throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let coordinator = ComputerUseAuthorizationCoordinator(authorization: store)

        let result = coordinator.pendingResult(
            applicationName: "Safari",
            bundleIdentifier: "com.apple.Safari",
            operation: "computer_observe"
        )

        let request = try #require(coordinator.request(from: result.content))
        #expect(request.applicationName == "Safari")
        #expect(request.bundleIdentifier == "com.apple.Safari")
        #expect(request.operation == "computer_observe")
    }

    @Test("非授权载荷不会被误认为授权请求")
    func foreignPayloadIsNotAnAuthorizationRequest() throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let coordinator = ComputerUseAuthorizationCoordinator(authorization: store)

        #expect(coordinator.request(from: "plain text result") == nil)
        #expect(coordinator.request(from: "{\"kind\":\"permission\"}") == nil)
    }

    @Test("渲染器只接管挂起中的 Computer Use 授权请求")
    func rendererOnlyClaimsItsOwnPayload() throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let coordinator = ComputerUseAuthorizationCoordinator(authorization: store)
        let renderer = ComputerUseAuthorizationRowRenderer(coordinator: coordinator)

        let suspended = ToolCall(
            id: "call-1",
            name: ComputerObserveV2Tool.toolName,
            arguments: "{}",
            result: coordinator.pendingResult(
                applicationName: "Safari",
                bundleIdentifier: "com.apple.Safari",
                operation: "computer_observe"
            )
        )
        #expect(renderer.canRender(toolCall: suspended))

        // 已完成：不再展示卡片。
        let finished = ToolCall(
            id: "call-2",
            name: ComputerObserveV2Tool.toolName,
            arguments: "{}",
            result: ToolCallResult(content: "done")
        )
        #expect(!renderer.canRender(toolCall: finished))

        // 用户已决定：不再展示卡片。
        var decided = suspended
        decided.authorizationState = .userApproved
        #expect(!renderer.canRender(toolCall: decided))

        // 其他工具的挂起：不接管，交给通用授权卡片。
        let foreign = ToolCall(
            id: "call-3",
            name: "some_other_tool",
            arguments: "{}",
            result: ToolCallResult(content: "{}", awaitingUserResponse: true)
        )
        #expect(!renderer.canRender(toolCall: foreign))
    }

    @Test("渲染器优先级高于通用工具授权卡片")
    func rendererOutranksGenericApproval() {
        #expect(ComputerUseAuthorizationRowRenderer.priority > 120)
    }
}

/// 决策落地后授权存储的实际变化。
@Suite("Computer Use 授权决策落地")
struct ComputerUseAuthorizationApplyTests {

    private func makeStore() -> (store: ComputerUseAuthorizationStore, directory: URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ComputerUseApply-\(UUID().uuidString)", isDirectory: true)
        return (ComputerUseAuthorizationStore(dataDirectory: directory), directory)
    }

    private let request = ComputerUseAuthorizationRequest(
        applicationName: "Safari",
        bundleIdentifier: "com.apple.Safari",
        operation: "computer_observe"
    )

    @Test("本任务内允许只产生会话作用域的授权")
    func allowForTaskGrantsSessionScopedAccess() throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let coordinator = ComputerUseAuthorizationCoordinator(authorization: store)
        let conversationID = UUID()

        coordinator.apply(
            decision: .allowForTask,
            request: request,
            conversationID: conversationID
        )

        #expect(store.hasSessionAccess(
            bundleIdentifier: "com.apple.Safari",
            conversationID: conversationID
        ))
        // 授权不跨会话：换一个对话必须重新申请。
        #expect(!store.hasSessionAccess(
            bundleIdentifier: "com.apple.Safari",
            conversationID: UUID()
        ))
    }

    @Test("拒绝不产生任何授权")
    func denyGrantsNothing() throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let coordinator = ComputerUseAuthorizationCoordinator(authorization: store)
        let conversationID = UUID()

        let message = coordinator.apply(
            decision: .deny,
            request: request,
            conversationID: conversationID
        )

        #expect(!store.hasSessionAccess(
            bundleIdentifier: "com.apple.Safari",
            conversationID: conversationID
        ))
        // 拒绝必须点名目标应用，模型才知道该放弃哪个目标。
        // 文案措辞随本地化变化，只断言与语言无关的契约。
        #expect(message.contains("Safari"))
    }
}

/// 工具挂起：命中未授权应用时挂起回合，而不是让整轮失败。
@Suite("Computer Use 工具授权挂起")
struct ComputerUseToolSuspensionTests {

    /// 隔离用的协调器：避免触碰 `ComputerUseRuntime.settingsDirectory()`。
    private func makeCoordinator() -> (coordinator: ComputerUseAuthorizationCoordinator, directory: URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ComputerUseSuspension-\(UUID().uuidString)", isDirectory: true)
        return (ComputerUseAuthorizationCoordinator(
            authorization: ComputerUseAuthorizationStore(dataDirectory: directory)
        ), directory)
    }

    @Test("授权请求被转换为挂起结果")
    func authorizationRequiredBecomesSuspension() async throws {
        let (coordinator, directory) = makeCoordinator()
        defer { try? FileManager.default.removeItem(at: directory) }

        let result = await ComputerUseToolSuspension.execute(
            operation: "computer_observe",
            coordinator: coordinator
        ) {
            throw ComputerUseError.authorizationRequired(
                applicationName: "Safari",
                bundleIdentifier: "com.apple.Safari",
                operation: "computer_observe"
            )
        }

        #expect(result.awaitingUserResponse)
        #expect(!result.isError)
        #expect(result.interactionState == .waiting)
    }

    @Test("其他错误按普通失败返回，不挂起回合")
    func otherErrorsDoNotSuspend() async throws {
        let (coordinator, directory) = makeCoordinator()
        defer { try? FileManager.default.removeItem(at: directory) }

        let result = await ComputerUseToolSuspension.execute(
            operation: "computer_observe",
            coordinator: coordinator
        ) {
            throw ComputerUseError.noMatchingWindow
        }

        #expect(!result.awaitingUserResponse)
        #expect(result.isError)
    }

    @Test("正常完成时原样透传结果")
    func successfulResultPassesThrough() async throws {
        let (coordinator, directory) = makeCoordinator()
        defer { try? FileManager.default.removeItem(at: directory) }

        let result = await ComputerUseToolSuspension.execute(
            operation: "computer_observe",
            coordinator: coordinator
        ) {
            ToolCallResult(content: "Observation captured.")
        }

        #expect(result.content == "Observation captured.")
        #expect(!result.awaitingUserResponse)
        #expect(!result.isError)
    }

    @Test("禁止类错误不会被误当成可申请授权")
    func forbiddenDoesNotSuspend() async throws {
        let (coordinator, directory) = makeCoordinator()
        defer { try? FileManager.default.removeItem(at: directory) }

        let result = await ComputerUseToolSuspension.execute(
            operation: "computer_observe",
            coordinator: coordinator
        ) {
            throw ComputerUseError.forbiddenApplication("Terminal apps cannot be automated.")
        }

        #expect(!result.awaitingUserResponse)
        #expect(result.isError)
        #expect(result.content.contains("Terminal apps"))
    }
}
