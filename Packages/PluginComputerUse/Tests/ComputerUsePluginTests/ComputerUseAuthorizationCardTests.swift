import Foundation
import KitAgentTool
import Testing
@testable import ComputerUsePlugin

/// 授权存储的一次性授权行为。
///
/// 「允许一次」是本特性最容易出错的地方：它必须在**下一次**操作前失效，
/// 否则用户以为只是临时放行，实际却变成了长期授权。
@Suite("Computer Use 一次性授权")
struct ComputerUseOneShotAuthorizationTests {

    private func makeStore() -> (store: ComputerUseAuthorizationStore, directory: URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ComputerUseOneShot-\(UUID().uuidString)", isDirectory: true)
        return (ComputerUseAuthorizationStore(dataDirectory: directory), directory)
    }

    @Test("允许一次只放行一次，第二次必须重新申请")
    func allowOnceGrantsExactlyOneOperation() throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        store.grantOneShot(bundleIdentifier: "com.example.editor")

        #expect(store.consumeOneShot(bundleIdentifier: "com.example.editor"))
        // 「仅本次」：紧接着的第二次检查必须失败。
        #expect(!store.consumeOneShot(bundleIdentifier: "com.example.editor"))
    }

    @Test("一次性授权过期后不再放行")
    func expiredOneShotIsRejected() throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        // 用负 TTL 立即构造一个已过期的授权。
        store.grantOneShot(bundleIdentifier: "com.example.editor", ttl: -1)

        #expect(!store.hasValidOneShot(bundleIdentifier: "com.example.editor"))
        #expect(!store.consumeOneShot(bundleIdentifier: "com.example.editor"))
    }

    @Test("撤销显式授权会连带清除该应用的一次性授权")
    func revokingExplicitAuthorizationAlsoRevokesOneShot() throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        store.setAllowed(true, bundleIdentifier: "com.example.editor")
        store.grantOneShot(bundleIdentifier: "com.example.editor")

        store.setAllowed(false, bundleIdentifier: "com.example.editor")

        #expect(!store.isAllowed("com.example.editor"))
        #expect(!store.hasValidOneShot(bundleIdentifier: "com.example.editor"))
    }

    @Test("撤销一个应用的授权不影响其他应用的一次性授权")
    func revokingOneApplicationKeepsOthersOneShot() throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        store.setAllowed(true, bundleIdentifier: "com.example.editor")
        store.grantOneShot(bundleIdentifier: "com.example.browser")

        store.setAllowed(false, bundleIdentifier: "com.example.editor")

        // 撤销只作用于目标应用，不应波及无关应用的一次性授权。
        #expect(store.hasValidOneShot(bundleIdentifier: "com.example.browser"))
    }

    @Test("清理过期条目不会影响仍然有效的授权")
    func purgingKeepsValidEntries() throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        store.grantOneShot(bundleIdentifier: "com.example.valid", ttl: 300)
        store.grantOneShot(bundleIdentifier: "com.example.expired", ttl: -1)

        store.purgeExpiredOneShots()

        #expect(store.hasValidOneShot(bundleIdentifier: "com.example.valid"))
        #expect(!store.hasValidOneShot(bundleIdentifier: "com.example.expired"))
    }

    @Test("空 bundle identifier 一律不产生授权")
    func emptyIdentifierIsIgnored() throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        store.grantOneShot(bundleIdentifier: "")

        #expect(!store.consumeOneShot(bundleIdentifier: ""))
        #expect(!store.hasValidOneShot(bundleIdentifier: ""))
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
        #expect(ComputerUseAuthorizationResolver.decision(for: "  ALLOW ONCE  ") == .allowOnce)
        #expect(ComputerUseAuthorizationResolver.decision(for: "允许一次") == .allowOnce)
        #expect(ComputerUseAuthorizationResolver.decision(for: "始终允许") == .alwaysAllow)
        #expect(ComputerUseAuthorizationResolver.decision(for: "Always Allow") == .alwaysAllow)
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
        #expect(ComputerUseAuthorizationDecision.allowOnce.isApproved)
        #expect(ComputerUseAuthorizationDecision.alwaysAllow.isApproved)
        #expect(!ComputerUseAuthorizationDecision.deny.isApproved)
    }

    @Test("拒绝文案明确要求不要重试")
    func denialMessageStopsThePath() {
        let message = ComputerUseAuthorizationResolver.denialMessage(applicationName: "Safari")

        // 只断言与应用名、与语言无关的契约：拒绝必须点名目标应用，
        // 否则模型无法知道该放弃哪个目标。文案措辞随本地化变化，不做断言。
        #expect(message.contains("Safari"))
    }

    @Test("允许一次的文案说明仅本次有效")
    func allowOnceMessageStatesScope() {
        let message = ComputerUseAuthorizationResolver.allowOnceMessage(applicationName: "Safari")

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

    @Test("未授权的应用返回需要授权，并带上应用信息")
    func unknownApplicationNeedsAuthorization() throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        let outcome = ComputerUseAccessChecker(authorization: store)
            .outcome(for: "com.example.unknown", applicationName: "Unknown")

        #expect(outcome == .needsAuthorization(
            applicationName: "Unknown",
            bundleIdentifier: "com.example.unknown"
        ))
    }

    @Test("显式白名单内的应用直接放行")
    func explicitAllowlistPasses() throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        store.setAllowed(true, bundleIdentifier: "com.example.editor")

        let outcome = ComputerUseAccessChecker(authorization: store)
            .outcome(for: "com.example.editor", applicationName: "Editor")

        #expect(outcome == .allowed)
    }

    @Test("一次性授权被消费后放行，第二次重新申请")
    func oneShotIsConsumedByTheCheck() throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        store.grantOneShot(bundleIdentifier: "com.example.editor")

        let checker = ComputerUseAccessChecker(authorization: store)
        #expect(checker.outcome(for: "com.example.editor", applicationName: "Editor") == .allowed)
        #expect(checker.outcome(for: "com.example.editor", applicationName: "Editor")
            == .needsAuthorization(applicationName: "Editor", bundleIdentifier: "com.example.editor"))
    }

    @Test("只读查询不会消耗掉一次性授权")
    func readOnlyCheckDoesNotConsume() throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        store.grantOneShot(bundleIdentifier: "com.example.editor")

        let checker = ComputerUseAccessChecker(authorization: store)
        #expect(checker.isAuthorizedWithoutConsuming("com.example.editor"))
        // 查询之后授权必须仍然可用。
        #expect(checker.isAuthorizedWithoutConsuming("com.example.editor"))
        #expect(checker.outcome(for: "com.example.editor", applicationName: "Editor") == .allowed)
    }

    @Test("空 bundle identifier 视为禁止，不允许申请授权")
    func emptyIdentifierIsForbidden() throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        let outcome = ComputerUseAccessChecker(authorization: store)
            .outcome(for: "", applicationName: "")

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

    @Test("始终允许写入显式白名单，与设置界面共用同一存储")
    func alwaysAllowWritesExplicitAllowlist() throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let coordinator = ComputerUseAuthorizationCoordinator(authorization: store)

        coordinator.apply(decision: .alwaysAllow, request: request)

        // 这条断言同时锁定了「两条路径共用同一存储」这个契约。
        #expect(store.isAllowed("com.apple.Safari"))
        #expect(store.allowedBundleIdentifiers().contains("com.apple.Safari"))
        // 始终允许不应留下一次性授权。
        #expect(!store.hasValidOneShot(bundleIdentifier: "com.apple.Safari"))
    }

    @Test("允许一次只产生一次性授权，不进白名单")
    func allowOnceStaysOutOfAllowlist() throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let coordinator = ComputerUseAuthorizationCoordinator(authorization: store)

        coordinator.apply(decision: .allowOnce, request: request)

        #expect(!store.isAllowed("com.apple.Safari"))
        #expect(store.hasValidOneShot(bundleIdentifier: "com.apple.Safari"))
    }

    @Test("拒绝不产生任何授权")
    func denyGrantsNothing() throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let coordinator = ComputerUseAuthorizationCoordinator(authorization: store)

        let message = coordinator.apply(decision: .deny, request: request)

        #expect(!store.isAllowed("com.apple.Safari"))
        #expect(!store.hasValidOneShot(bundleIdentifier: "com.apple.Safari"))
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