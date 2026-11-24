import Foundation
import KitAgentTool
import ProviderACP
import ProviderAgentLoop
import ProviderMessage

/// 回合执行窄协议。
///
/// 生产环境由 `AgentLoopProviding`（PluginAgentLoop）满足；
/// 测试注入轻量 mock，避免实现整个 agent loop 协议。
@MainActor
public protocol ACPTurnRunning: AnyObject {
    /// 注册回合生命周期观察者。
    func addAgentLoopObserver(
        _ callback: @escaping (AgentLoopEvent) -> Void
    ) -> any AgentLoopObserverHandle
    /// 启动一个回合。
    func runTurn(in conversationID: UUID) async throws -> AgentLoopOutcome
    /// 恢复被挂起的回合。
    func resumeTurn(in conversationID: UUID, request: AgentTurnResumeRequest) async throws -> AgentLoopOutcome
    /// 取消回合。
    func cancelTurn(in conversationID: UUID)
    /// 抑制/恢复该会话的自动回复（避免与内核自动回合竞争）。
    func setAutoReplySuppressed(_ suppressed: Bool, for conversationID: UUID)
}

/// 消息读写窄协议。
///
/// 生产环境由 `MessageManaging`（PluginConversationManager）满足。
@MainActor
public protocol ACPMessageReading: AnyObject {
    /// 插入一条消息（如用户提示）。
    func insertMessage(_ message: Message, to conversationID: UUID)
    /// 同步读取会话的全部消息快照。
    ///
    /// 必须为同步：ACP 回合收尾在事件路径上执行，异步存储（跨 actor /
    /// 持久化队列）会让 `finalize` 悬挂，导致 Client 收不到回合响应。
    func messagesSnapshot(in conversationID: UUID) -> [Message]
}

/// ACP 回合协调器：把 `session/prompt` 驱动的 Lumi agent 回合
/// 桥接为 ACP 的 `session/update` 通知流与最终 `session/prompt` 响应。
///
/// 事件映射（AgentLoopEvent → ACP）：
/// - `toolCallsReceived` → `session/update(tool_call)`，回合末补发 `tool_call_update`
/// - `suspended`（工具授权）→ `session/request_permission`（allow_once / reject_once），
///   允许后补发 `tool_call_update(in_progress)` 并恢复回合
/// - `suspended`（AskUser 交互）→ `session/request_permission`（yes_no/choice）
///   或降级为文本提示 + 结束回合（free_text / 非 JSON payload）
/// - `completed` / `failed` → 整段文本 `agent_message_chunk` + `end_turn`
/// - `cancelled` → `cancelled`
///
/// 所有出站 `request_permission` 都经 `ACPClientRequester` 发出并等待响应，
/// 因此响应到达、超时、会话取消三条路径都会收敛到同一个 continuation。
@MainActor
public final class ACPTurnCoordinator {
    /// 进行中的回合。
    private struct ActiveTurn {
        let sessionID: ACPSessionId
        let requestID: JSONValue
        let conversationID: UUID
        var finalized = false
        /// 是否已出现 LLM 进展（工具调用 / 终态事件）。
        /// started 不算进展：它只证明回合已启动，不能证明 LLM 会响应。
        var hasLLMProgress = false
        /// 本回合的 turnID（.started 事件登记，#220）。收尾补发只覆盖
        /// 本回合产生的消息，避免取消/空回合回放上一回合的内容。
        var turnID: UUID?
    }

    /// 已上报、可能进入授权流程的工具调用元数据。
    private struct ToolCallMetadata {
        let name: String
        let kind: ToolKind
        let title: String
        let rawInput: JSONValue?
    }

    /// 元数据登记键：会话 + 工具调用 ID。
    ///
    /// 不同会话可能上报相同的 toolCallId（如各会话首个调用都叫 "call_001"）。
    /// 仅以裸 ID 为键会让后写的会话覆盖先写的会话，授权弹窗展示错会话的
    /// 标题/入参（#353）。按 (sessionID, toolCallID) 隔离后互不串扰。
    private struct ToolCallKey: Hashable {
        let sessionID: ACPSessionId
        let toolCallID: String
    }

    /// 权限选项：optionId → 恢复回合时提交给内核的 answer。
    private struct PermissionOptions {
        let options: [ACPPermissionOption]
        let answersByOptionID: [String: String]
    }

    private let agentLoop: any ACPTurnRunning
    private let messages: any ACPMessageReading
    private let sessions: ACPSessionManager
    private let requester: ACPClientRequester
    /// 自动重试生命周期（可空：内核未装配重试插件时没有重试接管）。
    private let retryLifecycle: (any AgentLoopRetryLifecycleProviding)?
    /// 流式增量桥（可空：未接入流式时回合结束整段发送）。
    private let streaming: ACPStreamingBridge?
    private let onSend: @MainActor (ACPMessage) -> Void
    /// 回合启动后等待首个 LLM 进展的超时（无进展则按失败收尾，避免悬挂）。
    private let turnStartTimeout: TimeInterval

    private var activeTurns: [ACPSessionId: ActiveTurn] = [:]
    /// 正在等待用户决定的权限请求（每会话至多一个）。
    private var permissionTasks: [ACPSessionId: Task<Void, Never>] = [:]
    /// 已上报工具调用元数据（key: 会话 + toolCallId）。
    private var toolCallMetadata: [ToolCallKey: ToolCallMetadata] = [:]
    private var observerHandle: (any AgentLoopObserverHandle)?
    private var retryObserverHandle: (any AgentLoopRetryLifecycleObserverHandle)?
    private var watchdogTasks: [ACPSessionId: Task<Void, Never>] = [:]
    /// 启动 runner 的 Task 句柄（每会话一个）。
    ///
    /// `session/cancel` 可能与 `session/prompt` 同一 burst 到达，此时 runner
    /// 尚未创建 AgentLoop runtime，`cancelTurn` 是 no-op。持有句柄才能在
    /// `cancel()` 里取消这个尚未启动的 Task，让 `runTurnTask` 启动前看到取消
    /// 并跳过模型/工具，取消意图不会在启动前丢失（#480）。
    private var runnerTasks: [ACPSessionId: Task<Void, Never>] = [:]
    /// 内部兜底优雅结束的会话（AskUser 无法交互时主动停回合，非客户端取消）。
    private var gracefulStopConversations: Set<UUID> = []

    public init(
        agentLoop: any ACPTurnRunning,
        messages: any ACPMessageReading,
        sessions: ACPSessionManager,
        requester: ACPClientRequester,
        streaming: ACPStreamingBridge? = nil,
        retryLifecycle: (any AgentLoopRetryLifecycleProviding)? = nil,
        onSend: @escaping @MainActor (ACPMessage) -> Void,
        turnStartTimeout: TimeInterval? = nil
    ) {
        self.agentLoop = agentLoop
        self.messages = messages
        self.sessions = sessions
        self.requester = requester
        self.retryLifecycle = retryLifecycle
        self.streaming = streaming
        self.onSend = onSend
        // 默认 45 秒；支持 LUMI_ACP_TURN_TIMEOUT 环境变量覆盖（秒）。
        if let turnStartTimeout {
            self.turnStartTimeout = turnStartTimeout
        } else if let raw = ProcessInfo.processInfo.environment["LUMI_ACP_TURN_TIMEOUT"],
                  let seconds = TimeInterval(raw) {
            self.turnStartTimeout = seconds
        } else {
            self.turnStartTimeout = 45
        }
        observerHandle = agentLoop.addAgentLoopObserver { [weak self] event in
            self?.handle(event)
        }
        // 重试放弃时才向原 prompt 返回 refusal；重试成功 / 取消仍走
        // AgentLoop 自己的 completed / cancelled 事件。
        retryObserverHandle = retryLifecycle?.addRetryLifecycleObserver { [weak self] event in
            guard case .gaveUp(let conversationID, let reason) = event else { return }
            Task { @MainActor [weak self] in
                await self?.finalize(conversationID: conversationID, cancelled: false, errorText: reason)
            }
        }
        // 流式增量：内核追加 token 时立即转发为 agent_message_chunk。
        streaming?.onDelta = { [weak self] conversationID, delta in
            guard let self,
                  let sessionID = self.activeSessionID(for: conversationID) else { return }
            self.sendUpdate(sessionID: sessionID, update: .agentMessageChunk(.text(delta)))
        }
        // 任何流式增量（正文或思考 token）都证明 LLM 正在产出：据此解除首响应
        // watchdog，否则持续健康流式的长回答会被误判为「无 LLM 进展」而拒绝（#352）。
        streaming?.onProgress = { [weak self] conversationID in
            self?.markLLMProgress(conversationID: conversationID)
        }
    }

    // MARK: - 回合启动

    /// 启动一个 ACP 回合：插入用户消息 → 运行 agent 回合。
    ///
    /// - Parameters:
    ///   - sessionID: ACP 会话。
    ///   - requestID: `session/prompt` 的 JSON-RPC 请求 ID（最终响应回执）。
    ///   - prompt: 用户提示块（支持 text / resource / resourceLink；image/audio 忽略）。
    /// - Returns: 错误消息（同步校验失败时），否则 nil 表示回合已启动。
    public func startTurn(
        sessionID: ACPSessionId,
        requestID: JSONValue,
        prompt: [ContentBlock]
    ) -> String? {
        guard let record = sessions.record(for: sessionID) else {
            return "Unknown session: \(sessionID.rawValue)"
        }
        let text = Self.text(from: prompt)
        guard !text.isEmpty else {
            return "Prompt must contain text content"
        }
        guard activeTurns[sessionID] == nil else {
            return "Session already has an active turn: \(sessionID.rawValue)"
        }

        let userMessage = Message(
            conversationID: record.conversationID,
            role: .user,
            content: text
        )
        // 先抑制自动回复，再插入用户消息：内核 MessageObserver 会因
        // 消息插入自动启动回合，ACP 需要独占托管本回合。
        agentLoop.setAutoReplySuppressed(true, for: record.conversationID)
        messages.insertMessage(userMessage, to: record.conversationID)
        activeTurns[sessionID] = ActiveTurn(
            sessionID: sessionID,
            requestID: requestID,
            conversationID: record.conversationID
        )
        armWatchdog(sessionID: sessionID)

        runnerTasks[sessionID] = Task { @MainActor [weak self] in
            await self?.runTurnTask(sessionID: sessionID, conversationID: record.conversationID)
        }
        return nil
    }

    // MARK: - 首响应超时兜底

    /// 回合启动后若在 `turnStartTimeout` 内没有任何 LLM 进展
    /// （工具调用 / 终态事件），按失败收尾，避免 Client 悬挂。
    private func armWatchdog(sessionID: ACPSessionId) {
        watchdogTasks[sessionID]?.cancel()
        watchdogTasks[sessionID] = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(self?.turnStartTimeout ?? 45))
            guard let self else { return }
            guard let turn = self.activeTurns[sessionID], !turn.finalized else { return }
            guard !turn.hasLLMProgress else { return }
            // 只发 refusal 不取消底层回合的话，模型晚回包后工具仍会照常执行，
            // 产生客户端既不能停止也观察不到的副作用（#222）。先取消再收尾，
            // 与 session/cancel 路径一致；finalize 的 finalized 标志保证随后
            // 到达的 cancelled 事件不会重复响应。
            self.agentLoop.cancelTurn(in: turn.conversationID)
            await self.finalize(
                conversationID: turn.conversationID,
                cancelled: false,
                errorText: "Agent did not produce a response (no LLM progress within \(Int(self.turnStartTimeout))s). Check that a model is configured."
            )
        }
    }

    /// 取消会话进行中的回合（`session/cancel` 通知）。
    ///
    /// ACP 要求：收到取消后，该会话所有挂起的 `session/request_permission`
    /// 立即以 `cancelled` 收尾，避免 Client 悬挂。
    public func cancel(sessionID: ACPSessionId) {
        guard let record = sessions.record(for: sessionID) else { return }
        cancelPendingPermissions(sessionID: sessionID)
        // runner Task 可能尚未启动（prompt 与 cancel 同一 burst）：此刻 AgentLoop
        // runtime 还没创建，下面的 cancelTurn 是 no-op。先取消 runner Task，让
        // runTurnTask 启动前据此跳过模型/工具，取消意图不会在启动前丢失（#480）。
        runnerTasks[sessionID]?.cancel()
        // 退避中的回合不处于运行态，`cancelTurn` 不会产生 cancelled 事件；
        // 必须显式终止重试，并由 ACP 自己完成收尾，否则原请求一直悬挂。
        retryLifecycle?.cancelRetry(for: record.conversationID)
        agentLoop.cancelTurn(in: record.conversationID)
        Task { @MainActor [weak self] in
            await self?.finalize(conversationID: record.conversationID, cancelled: true, errorText: nil)
        }
    }

    // MARK: - 事件处理

    private func handle(_ event: AgentLoopEvent) {
        switch event {
        case .started(let conversationID, let turnID):
            recordTurnID(turnID, conversationID: conversationID)
        case .resumed:
            break
        case .toolCallsReceived(let conversationID, _, _, let toolCalls):
            markLLMProgress(conversationID: conversationID)
            reportToolCalls(conversationID: conversationID, toolCalls: toolCalls)
        case .llmResponseReceived(let conversationID, _, _):
            markLLMProgress(conversationID: conversationID)
        case .suspended(_, _, let suspension):
            markLLMProgress(conversationID: suspension.conversationID)
            handleSuspension(suspension)
        case .completed(let conversationID, _):
            markLLMProgress(conversationID: conversationID)
            Task { @MainActor [weak self] in
                await self?.finalize(conversationID: conversationID, cancelled: false, errorText: nil)
            }
        case .failed(let conversationID, _, let reason):
            markLLMProgress(conversationID: conversationID)
            Task { @MainActor [weak self] in
                await self?.finalize(conversationID: conversationID, cancelled: false, errorText: reason)
            }
        case .cancelled(let conversationID, _):
            markLLMProgress(conversationID: conversationID)
            // 优雅结束（AskUser 兜底）产生的 .cancelled 不代表客户端取消，
            // 必须以 end_turn 收尾（#482）。
            let graceful = consumeGracefulStop(conversationID)
            Task { @MainActor [weak self] in
                await self?.finalize(conversationID: conversationID, cancelled: !graceful, errorText: nil)
            }
        }
    }

    /// 记录 LLM 进展：任何工具调用 / 终态事件到达后，watchdog 不再触发。
    private func markLLMProgress(conversationID: UUID) {
        guard let sessionID = activeSessionID(for: conversationID) else { return }
        activeTurns[sessionID]?.hasLLMProgress = true
        watchdogTasks[sessionID]?.cancel()
        watchdogTasks[sessionID] = nil
    }

    /// 登记 .started 事件的 turnID（#220）：收尾时以此限定补发范围。
    private func recordTurnID(_ turnID: UUID, conversationID: UUID) {
        guard let sessionID = activeSessionID(for: conversationID) else { return }
        activeTurns[sessionID]?.turnID = turnID
    }

    private func runTurnTask(sessionID: ACPSessionId, conversationID: UUID) async {
        // 启动前已被取消（#480）：prompt 与 cancel 同一 burst 到达时 runner 尚未
        // 创建 runtime，cancelTurn 是 no-op，cancel() 改为取消本 Task。这里必须在
        // 启动模型/工具前看到取消并跳过 runner；收尾由 cancel() 已调度的
        // finalize(cancelled:true) 负责，不在此重复收尾。取消标志随本回合 Task
        // 存续，startTurn 用新 Task 覆盖句柄，不会污染同一会话的下一回合。
        if Task.isCancelled {
            return
        }
        do {
            let outcome = try await agentLoop.runTurn(in: conversationID)
            // 事件路径已 finalize 的回合会因 finalized 标志跳过。
            switch outcome {
            case .completed:
                await finalize(conversationID: conversationID, cancelled: false, errorText: nil)
            case .failed(let reason):
                if reason.contains("already running") {
                    // 内核自动回复（MessageObserver）已接管该回合：
                    // 由事件路径收尾，这里不重复 finalize。
                    break
                }
                await finalize(conversationID: conversationID, cancelled: false, errorText: reason)
            case .cancelled:
                // 事件路径可能已消费优雅标记并收尾（finalized 守卫兜底）；
                // 这里同样消费，谁先看到标记谁负责按 end_turn 收尾（#482）。
                let graceful = consumeGracefulStop(conversationID)
                await finalize(conversationID: conversationID, cancelled: !graceful, errorText: nil)
            case .suspended:
                // 回合挂起等待用户决定（resume 后继续），不结束。
                break
            }
        } catch {
            // runTurn 异常（如恢复失败）：按取消结束，避免客户端悬挂。
            await finalize(conversationID: conversationID, cancelled: true, errorText: nil)
        }
    }

    // MARK: - 工具调用通知

    private func reportToolCalls(conversationID: UUID, toolCalls: [MessageToolCall]) {
        guard let sessionID = activeSessionID(for: conversationID) else { return }
        for call in toolCalls {
            let kind = Self.toolKind(for: call.name)
            let title = call.displayDescription ?? call.name
            let rawInput = Self.json(from: call.arguments)
            // 登记元数据：授权弹窗需要真实 toolCallId / 标题 / 类别 / 原始入参。
            toolCallMetadata[ToolCallKey(sessionID: sessionID, toolCallID: call.id)] = ToolCallMetadata(
                name: call.name,
                kind: kind,
                title: title,
                rawInput: rawInput
            )
            sendUpdate(sessionID: sessionID, update: .toolCall(ToolCallUpdate(
                toolCallId: call.id,
                title: title,
                kind: kind,
                status: .pending,
                rawInput: rawInput
            )))
        }
    }

    // MARK: - 挂起处理

    /// 内核只有 `cancelTurn` 一种停止回合的手段，但它固定产生 `.cancelled`；
    /// ACP 语义里 `cancelled` 专指客户端取消。AskUser 兜底（无自由文本通道、
    /// 载荷缺失、选项为空）是协调者主动结束回合让用户下轮回答，不是取消，
    /// 必须先登记优雅结束标记，让随后的 `.cancelled` 映射为 end_turn（#482）。
    private func stopTurnGracefully(_ conversationID: UUID) {
        gracefulStopConversations.insert(conversationID)
        agentLoop.cancelTurn(in: conversationID)
    }

    /// 消费优雅结束标记；返回 true 表示该 `.cancelled` 来自内部兜底而非客户端。
    private func consumeGracefulStop(_ conversationID: UUID) -> Bool {
        gracefulStopConversations.remove(conversationID) != nil
    }

    private func handleSuspension(_ suspension: AgentLoopSuspension) {
        guard let sessionID = sessions.sessionID(for: suspension.conversationID),
              activeTurns[sessionID] != nil else { return }

        let payload = Self.jsonObject(from: suspension.payload)

        // 工具授权挂起：内核以 payload.kind == "permission" 标记。
        // 判据来自共享契约（`ToolSuspensionKind`），不硬编码字面量——
        // 契约的键名与取值由 `KitAgentTool` 统一拥有。
        if ToolSuspensionKind.isPermissionRequest(suspension.payload) {
            presentToolPermission(suspension, payload: payload, sessionID: sessionID)
            return
        }

        // 其余为 AskUser 交互（需要 payload.mode 判别）。
        guard let mode = payload?["mode"] as? String else {
            // 非 AskUser 载荷：把 payload 作为问题文本推送，并结束回合。
            sendAgentText(suspension.payload, sessionID: sessionID)
            stopTurnGracefully(suspension.conversationID)
            return
        }

        let question = (payload?["question"] as? String) ?? suspension.payload
        switch mode {
        case "choice":
            let labels = Self.choiceOptions(from: payload?["options"])
            guard !labels.isEmpty else {
                sendAgentText(ACPLocalization.inputRequired(question), sessionID: sessionID)
                stopTurnGracefully(suspension.conversationID)
                return
            }
            // AskUser 的 answer 必须是选项标签本身（内核按标签匹配）；optionId
            // 也用标签，因为标签可能含空格/任意语言，不适合作为稳定标识。
            let options = PermissionOptions(
                options: labels.map { ACPPermissionOption(optionId: $0, name: $0, kind: .allowOnce) },
                answersByOptionID: Dictionary(uniqueKeysWithValues: labels.map { ($0, $0) })
            )
            awaitPermission(
                suspension: suspension,
                sessionID: sessionID,
                toolCallUpdate: ToolCallUpdate(
                    toolCallId: suspension.toolCallID ?? "ask-\(suspension.suspensionID)",
                    title: question,
                    status: .pending
                ),
                options: options
            )
        case "free_text":
            // ACP 无自由文本输入通道：降级为文本问题 + 结束回合，用户下轮回答。
            sendAgentText(ACPLocalization.inputRequired(question), sessionID: sessionID)
            stopTurnGracefully(suspension.conversationID)
        default: // yes_no
            // 展示文案走本地化，但 answer 固定传内核可识别的允许/拒绝词，
            // 否则非中文环境下用户点"允许"会被内核当成拒绝执行。
            let options = PermissionOptions(
                options: [
                    ACPPermissionOption(optionId: "yes", name: ACPLocalization.yes, kind: .allowOnce),
                    ACPPermissionOption(optionId: "no", name: ACPLocalization.no, kind: .rejectOnce),
                ],
                answersByOptionID: ["yes": "approved", "no": "denied"]
            )
            awaitPermission(
                suspension: suspension,
                sessionID: sessionID,
                toolCallUpdate: ToolCallUpdate(
                    toolCallId: suspension.toolCallID ?? "ask-\(suspension.suspensionID)",
                    title: question,
                    status: .pending
                ),
                options: options
            )
        }
    }

    /// 工具授权挂起：以真实 `toolCallId` 发起 `session/request_permission`。
    private func presentToolPermission(
        _ suspension: AgentLoopSuspension,
        payload: [String: Any]?,
        sessionID: ACPSessionId
    ) {
        // 用真实 toolCallId（内核授权挂起的 suspension.toolCallID 即模型原始调用 ID），
        // 与先前上报的 `tool_call` 通知保持一致；payload 里的 "approval:<id>" 不可用。
        let toolCallID = suspension.toolCallID ?? ""
        // 只取本会话登记的元数据：裸 ID 可能命中其它会话的同名调用（#353）。
        let metadata = toolCallMetadata[ToolCallKey(sessionID: sessionID, toolCallID: toolCallID)]
        let question = (payload?["question"] as? String) ?? ACPLocalization.allowThisOperation

        let options = PermissionOptions(
            options: [
                ACPPermissionOption(optionId: "allow_once", name: ACPLocalization.allow, kind: .allowOnce),
                ACPPermissionOption(optionId: "reject_once", name: ACPLocalization.reject, kind: .rejectOnce),
            ],
            // 展示文案随系统语言变化，但 answer 必须是内核能识别的允许词，
            // 否则非中文环境下"允许"会被 resolveUserResponse 判为拒绝。
            answersByOptionID: ["allow_once": "approved", "reject_once": "denied"]
        )
        awaitPermission(
            suspension: suspension,
            sessionID: sessionID,
            toolCallUpdate: ToolCallUpdate(
                toolCallId: toolCallID,
                title: metadata?.title ?? question,
                kind: metadata?.kind,
                status: .pending,
                rawInput: metadata?.rawInput
            ),
            options: options
        )
    }

    /// 发起权限请求并异步处理用户决定（allow / reject / cancel / 超时）。
    private func awaitPermission(
        suspension: AgentLoopSuspension,
        sessionID: ACPSessionId,
        toolCallUpdate: ToolCallUpdate,
        options: PermissionOptions
    ) {
        guard permissionTasks[sessionID] == nil else {
            // 同一会话已有一个待决定权限：拒绝并发挂起，避免响应错配。
            agentLoop.cancelTurn(in: suspension.conversationID)
            return
        }

        let params = ACPRequestPermissionParams(
            sessionId: sessionID,
            toolCall: toolCallUpdate,
            options: options.options
        )

        permissionTasks[sessionID] = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.permissionTasks[sessionID] = nil }

            let outcome: ACPRequestPermissionResult
            do {
                outcome = try await self.requester.requestPermission(params)
            } catch {
                // 客户端无响应（超时）或连接中断：终止回合，避免悬挂。
                self.agentLoop.cancelTurn(in: suspension.conversationID)
                return
            }

            switch outcome.outcome {
            case .cancelled:
                self.agentLoop.cancelTurn(in: suspension.conversationID)
            case .selected(let optionId):
                guard let answer = options.answersByOptionID[optionId] else {
                    self.agentLoop.cancelTurn(in: suspension.conversationID)
                    return
                }
                // 授权通过：先按 ACP 规范把工具置为 in_progress，再恢复回合。
                if optionId.hasPrefix("allow") {
                    self.sendUpdate(
                        sessionID: sessionID,
                        update: .toolCallUpdate(ToolCallUpdate(
                            toolCallId: toolCallUpdate.toolCallId,
                            status: .inProgress
                        ))
                    )
                }
                _ = try? await self.agentLoop.resumeTurn(
                    in: suspension.conversationID,
                    request: AgentTurnResumeRequest(
                        suspensionID: suspension.suspensionID,
                        answer: answer
                    )
                )
            }
        }
    }

    /// 作废会话的挂起权限请求（回合收尾 / 取消时调用）。
    private func cancelPendingPermissions(sessionID: ACPSessionId) {
        permissionTasks[sessionID]?.cancel()
        permissionTasks[sessionID] = nil
        requester.cancelRequests(for: sessionID)
    }

    // MARK: - 回合收尾

    private func finalize(conversationID: UUID, cancelled: Bool, errorText: String?) async {
        guard let (sessionID, turn) = activeTurns.first(where: { $0.value.conversationID == conversationID }),
              !turn.finalized else {
            return
        }

        // 可重试失败可能已被自动重试接管：回合尚未结束，不能提前向原
        // prompt 返回终态，否则后续重试的进度与结果无法再关联到该请求。
        if !cancelled, errorText != nil,
           retryLifecycle?.isRetrying(conversationID: conversationID) == true {
            return
        }

        activeTurns[sessionID]?.finalized = true

        // #220：补发范围限定为本回合产生的消息。取消且回合从未真正启动
        // （没有 turnID）时，历史回合的终态已在其自身收尾时补发过，不能重放。
        let currentTurnID = turn.turnID
        // ACP 要求：回合结束前不得残留挂起的权限请求；未完成的工具调用
        // 一律以 cancelled 收尾，Client 才能正确收敛 UI 状态。
        cancelPendingPermissions(sessionID: sessionID)
        publishCancelledToolCalls(sessionID: sessionID)
        // 失败回合同样要收敛工具状态：已落库的结果补发 completed/failed，
        // 否则客户端的工具行永久停在 pending（#481）。
        if currentTurnID != nil || !cancelled {
            publishTerminalToolUpdates(
                conversationID: conversationID,
                sessionID: sessionID,
                turnID: currentTurnID
            )
        }

        // stopReason 必须如实反映回合结局：把失败混成 end_turn 会让客户端
        // 把错误当成功（方案 §5 约定 failed → refusal）。因此先判定是否失败。
        let failed = !cancelled && errorText != nil
        if let errorText {
            sendAgentText(errorText, sessionID: sessionID)
        }
        // #220：取消回合不做最终文本回填——此刻本回合通常还没有 assistant
        // 消息，旧逻辑会取到上一回合的整段回复回放给客户端。
        if !cancelled, !failed {
            await publishFinalContent(
                conversationID: conversationID,
                sessionID: sessionID,
                turnID: currentTurnID
            )
        }
        streaming?.reset(conversationID: conversationID)

        let stopReason: StopReason
        if cancelled {
            stopReason = .cancelled
        } else if failed {
            stopReason = .refusal
        } else if let lastStop = messages.messagesSnapshot(in: conversationID)
            .reversed()
            .first(where: { $0.role == .assistant })?.stopReason,
            lastStop == "length" || lastStop == "max_tokens" {
            // #354：token 截断（OpenAI finish_reason=length / Anthropic
            // stop_reason=max_tokens）已随 assistant 消息落库，如实映射成
            // ACP 的 max_tokens，不要与自然完成一样折叠成 end_turn。
            stopReason = .maxTokens
        } else {
            stopReason = .endTurn
        }
        do {
            onSend(try ACPMessage.makeResponse(
                id: turn.requestID,
                result: ACPPromptResult(stopReason: stopReason)
            ))
        } catch {
            onSend(.error(id: turn.requestID, error: .internalError))
        }

        activeTurns.removeValue(forKey: sessionID)
        watchdogTasks[sessionID]?.cancel()
        watchdogTasks[sessionID] = nil
        // 回合结束：恢复自动回复（该会话回到内核默认行为）。
        agentLoop.setAutoReplySuppressed(false, for: conversationID)
    }

    /// 回合结束时，把本会话尚未出结果的工具调用标记为 cancelled。
    private func publishCancelledToolCalls(sessionID: ACPSessionId) {
        let snapshot = messages.messagesSnapshot(in: sessions.conversationID(for: sessionID) ?? UUID())
        let completedIDs = Set(
            snapshot.flatMap { $0.toolCalls ?? [] }
                .filter { $0.result != nil }
                .map(\.id)
        )
        let pendingIDs = toolCallMetadata
            .filter { $0.key.sessionID == sessionID && !completedIDs.contains($0.key.toolCallID) }
            .map(\.key.toolCallID)
        for toolCallID in pendingIDs {
            sendUpdate(sessionID: sessionID, update: .toolCallUpdate(ToolCallUpdate(
                toolCallId: toolCallID,
                status: .cancelled
            )))
        }
        toolCallMetadata = toolCallMetadata.filter { $0.key.sessionID != sessionID }
    }

    /// 补发已落库工具结果的终态（completed/failed）。
    ///
    /// 成功与失败路径都必须调用：失败回合虽然跳过最终文本，但工具结果
    /// 是已经落库的事实，不补发会让客户端的工具行永久停在 pending（#481）。
    /// `turnID` 非 nil 时只补发该回合的消息（#220）；nil 表示回合未登记
    /// turnID，保持全量扫描的旧行为。
    private func publishTerminalToolUpdates(
        conversationID: UUID,
        sessionID: ACPSessionId,
        turnID: UUID?
    ) {
        let snapshot = messages.messagesSnapshot(in: conversationID)
        for message in snapshot.reversed() where message.role == .assistant {
            if let turnID, message.turnID != turnID { continue }
            for call in message.toolCalls ?? [] {
                guard let result = call.result else { continue }
                sendUpdate(
                    sessionID: sessionID,
                    update: .toolCallUpdate(ToolCallUpdate(
                        toolCallId: call.id,
                        status: result.isError ? .failed : .completed,
                        content: [.content(.text(result.content))]
                    ))
                )
            }
        }
    }

    /// 回合正常结束后：补发最终 assistant 文本。
    ///
    /// `turnID` 非 nil 时只取该回合产生的消息（#220）——否则新回合尚无
    /// 内容时会取到上一回合的整段回复回放给客户端。
    private func publishFinalContent(
        conversationID: UUID,
        sessionID: ACPSessionId,
        turnID: UUID?
    ) async {
        let snapshot = messages.messagesSnapshot(in: conversationID)
        var assistantMessages = snapshot.reversed().filter { $0.role == .assistant }
        if let turnID {
            assistantMessages = assistantMessages.filter { $0.turnID == turnID }
        }

        // 最终 assistant 文本（第一个非空内容）。
        // 已经流式发出过增量的回合不再整段重发，否则客户端会看到重复文本。
        if streaming?.didStream(conversationID: conversationID) != true,
           let finalText = assistantMessages.first(where: { !$0.content.isEmpty })?.content {
            sendAgentText(finalText, sessionID: sessionID)
        }
    }

    // MARK: - 发送辅助

    private func sendUpdate(sessionID: ACPSessionId, update: SessionUpdate) {
        do {
            onSend(try ACPMessage.makeNotification(
                method: ACPMethod.sessionUpdate,
                params: ACPSessionUpdateParams(sessionId: sessionID, update: update)
            ))
        } catch {
            fputs("ACP update encode failed: \(error)\n", stderr)
        }
    }

    private func sendAgentText(_ text: String, sessionID: ACPSessionId) {
        sendUpdate(sessionID: sessionID, update: .agentMessageChunk(.text(text)))
    }

    /// 从活动回合定位 conversationID 对应的 ACP 会话。
    private func activeSessionID(for conversationID: UUID) -> ACPSessionId? {
        activeTurns.first(where: { $0.value.conversationID == conversationID })?.key
    }

    // MARK: - 纯函数

    /// 提取提示中的文本内容（text / resource / resourceLink）。
    static func text(from blocks: [ContentBlock]) -> String {
        blocks.compactMap { block -> String? in
            switch block {
            case .text(let text, _):
                return text
            case .resource(let resource, _):
                return resource.text ?? resource.uri
            case .resourceLink(let uri, _, _, _, _, _, _):
                return uri
            case .image, .audio:
                return nil
            }
        }
        .filter { !$0.isEmpty }
        .joined(separator: "\n\n")
    }

    /// 根据工具名推断 ACP ToolKind。
    static func toolKind(for name: String) -> ToolKind {
        let n = name.lowercased()
        if n.contains("read") || n.contains("open") || n.contains("view") { return .read }
        if n.contains("write") || n.contains("edit") || n.contains("replace") { return .edit }
        if n.contains("delete") || n.contains("remove") || n.contains("trash") { return .delete }
        if n.contains("move") || n.contains("rename") || n.contains("copy") { return .move }
        if n.contains("search") || n.contains("find") || n.contains("query") { return .search }
        if n.contains("bash") || n.contains("terminal") || n.contains("shell") || n.contains("run") || n.contains("execute") { return .execute }
        if n.contains("fetch") || n.contains("http") || n.contains("web") { return .fetch }
        if n.contains("think") || n.contains("plan") { return .think }
        return .other
    }

    /// 把 JSON 字符串解析为 JSONValue（失败返回 nil）。
    static func json(from string: String) -> JSONValue? {
        try? JSONDecoder().decode(JSONValue.self, from: Data(string.utf8))
    }

    /// 把 JSON 字符串解析为字典（失败或非对象返回 nil）。
    static func jsonObject(from string: String) -> [String: Any]? {
        guard let data = string.data(using: .utf8) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    /// 解析 AskUser choice 选项（对象 {label,description?,badge?} 或裸字符串）。
    static func choiceOptions(from raw: Any?) -> [String] {
        guard let array = raw as? [Any] else { return [] }
        let labels = array.compactMap { element -> String? in
            if let string = element as? String, !string.isEmpty { return string }
            if let dict = element as? [String: Any] {
                let label = (dict["label"] as? String)
                    ?? (dict["description"] as? String)
                    ?? (dict["value"] as? String)
                    ?? (dict["text"] as? String)
                return label.flatMap { $0.isEmpty ? nil : $0 }
            }
            return nil
        }
        // 去重并保持首次出现顺序：labels 同时用作 optionId 与 answersByOptionID
        // 的键，重复标签会让 Dictionary(uniqueKeysWithValues:) 运行时陷阱崩溃（#221）。
        var seen = Set<String>()
        return labels.filter { seen.insert($0).inserted }
    }
}

/// `session/update` 通知参数（sessionId + update 载荷）。
public struct ACPSessionUpdateParams: Sendable, Equatable, Codable {
    public var sessionId: ACPSessionId
    public var update: SessionUpdate

    public init(sessionId: ACPSessionId, update: SessionUpdate) {
        self.sessionId = sessionId
        self.update = update
    }
}
