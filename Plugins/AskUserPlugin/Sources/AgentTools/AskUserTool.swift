import AgentToolKit
import Foundation
import LumiKernel
import os
import SuperLogKit

/// 询问用户工具
///
/// 让 LLM 可以向用户提问并等待回答。支持是/否确认、多选项选择和自由输入。
/// 当 LLM 需要用户确认操作或获取用户偏好时使用此工具。
///
/// ## 工作流程
///
/// 1. LLM 调用 ask_user 工具（必须显式传 `mode`）
/// 2. 工具返回结构化的 `AgentTurnControl.suspend` + JSON payload
/// 3. AgentTurnManager 记录暂停状态并结束当前 turn
/// 4. UI 渲染选择界面，用户点击选项
/// 5. AskUserBridge 直接调用 AgentTurnManager.resumeTurn
/// 7. LLM 收到用户的回答作为 tool result，继续处理
public struct AskUserTool: LumiAgentTool, SuperLog {
    public nonisolated static let emoji = "❓"

    public nonisolated static let verbose: Bool = false
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "tool.ask-user")

    public static let info = LumiAgentToolInfo(
        id: "ask_user",
        displayName: "Ask User",
        description: """
        Ask the user a question and wait for their response. Use when you need a user decision instead of assuming intent.

        FIRST choose a `mode`, then fill the other parameters to match it:
        - mode="yes_no": the question can be genuinely answered with 是 or 否. Do NOT pass options. Example: "继续构建?"
        - mode="choice": the answer must be one of a fixed set. You MUST pass a non-empty `options` array. Example: options=["Debug", "Release", "Profile"].
        - mode="free_text": the question is open-ended and cannot be answered by yes/no or a fixed set. Do NOT pass options. Example: "冲突如何处理?", "接下来怎么做?", "想用什么分支名?".

        CRITICAL — do NOT use mode="yes_no" for open-ended questions (anything asking how/why/what-next/which-plan). Those MUST use mode="free_text" (single answer) or mode="choice" (you supply the candidates). A yes/no dialog rendered for an open-ended question is a bug.
        """
    )

    public init() {}

    // MARK: - LumiAgentTool

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "question": .object([
                    "type": .string("string"),
                    "description": .string("Question to ask the user (e.g.: Should I continue?)"),
                ]),
                "mode": .object([
                    "type": .string("string"),
                    "enum": .array([.string("yes_no"), .string("choice"), .string("free_text")]),
                    "description": .string("REQUIRED interaction mode. yes_no = answerable with 是/否 (no options); choice = pick from a fixed set (must pass options); free_text = open-ended question (no options). Pick the mode that matches the question, not yes_no for everything."),
                ]),
                "options": .object([
                    "type": .string("array"),
                    "items": .object([
                        "type": .string("object"),
                        "properties": .object([
                            "label": .object([
                                "type": .string("string"),
                                "description": .string("Short button text; also the value returned as the user's answer."),
                            ]),
                            "description": .object([
                                "type": .string("string"),
                                "description": .string("Optional longer explanation shown under the label."),
                            ]),
                        ]),
                        "required": .array([.string("label")]),
                    ]),
                    "description": .string("Required when mode=\"choice\". Each item is {label, description?} (bare strings also accepted). Ignored for yes_no / free_text."),
                ]),
            ]),
            "required": .array([.string("question"), .string("mode")]),
        ])
    }

    public func execute(arguments: [String: LumiJSONValue], kernel: LumiKernel) async throws -> String {
        guard let question = arguments.string("question"), !question.isEmpty else {
            return Self.errorResult(message: "question is required and cannot be empty")
        }

        // mode 是必填的强制函数：LLM 必须先声明意图，杜绝「偷懒默认 yes_no」。
        let mode = Self.resolvedMode(arguments)
        guard let resolvedMode = mode else {
            return Self.errorResult(
                message: "mode is required. Choose one of: yes_no (是/否), choice (pick from options), free_text (open-ended)."
            )
        }

        // mode=choice 必须带 options
        let options = Self.resolvedOptions(arguments, mode: resolvedMode)
        if resolvedMode == "choice" {
            guard !options.isEmpty, arguments["options"] != nil else {
                return Self.errorResult(
                    message: "mode=choice requires a non-empty options array. Pass options=[...] with the candidates, or switch to free_text."
                )
            }
        }

        // 交叉校验（安全网）：拦截「明明是开放/多选问题却选了 yes_no」的误用。
        if resolvedMode == "yes_no" {
            if Self.lookLikeOpenEnded(question) {
                return Self.errorResult(
                    message: "mode=yes_no does not match this open-ended question. Use mode=\"free_text\" instead."
                )
            }
            if !options.isEmpty, Self.lookLikeMultipleChoice(question) {
                return Self.errorResult(
                    message: "mode=yes_no does not match a multiple-choice question. Use mode=\"choice\" with options=[...]."
                )
            }
        }

        logInvocation(question: question, mode: resolvedMode, options: options)

        let pendingResponse = Self.buildPendingResponse(
            kernel: kernel,
            question: question,
            options: options,
            mode: resolvedMode
        )

        let payload = try Self.encodePendingPayload(pendingResponse)
        return payload
    }

    public func executeResult(
        arguments: [String: LumiJSONValue],
        kernel: LumiKernel
    ) async throws -> LumiToolExecutionResult {
        let content = try await execute(arguments: arguments, kernel: kernel)
        guard let data = content.data(using: .utf8),
              let response = try? JSONDecoder().decode(AskUserPendingResponse.self, from: data),
              let conversationID = UUID(uuidString: response.conversationId)
        else {
            return LumiToolExecutionResult(
                content: content,
                isError: content.hasPrefix(LumiAskUserMarkers.errorPrefix)
            )
        }

        let suspension = AgentTurnSuspension(
            suspensionID: response.toolCallId,
            conversationID: conversationID,
            toolCallID: response.toolCallId,
            kind: "userInput",
            payload: content
        )
        return LumiToolExecutionResult(
            content: content,
            turnControl: .suspend(suspension)
        )
    }

    // MARK: - Mode & Option Resolution

    /// 解析 `mode` 参数；只接受三个合法值，否则返回 nil（由 execute 报错）。
    static func resolvedMode(_ arguments: [String: LumiJSONValue]) -> String? {
        guard let raw = arguments.string("mode") else { return nil }
        return allowedModes.contains(raw) ? raw : nil
    }

    /// 按 `mode` 归一化 `options`：
    /// - `yes_no` → 强制是/否（忽略传入的 options）
    /// - `choice` → 用传入的 options（execute 已保证非空；兜底回退默认）
    /// - `free_text` → 空数组（视图改用输入框）
    ///
    /// choice 分支自己遍历数组，兼容两种形态：对象取 `{label, description?}`，
    /// 字符串降级为 `{label}`。**关键：对象不再被静默丢弃**（旧 `stringArray` 会把对象过滤成 nil）。
    static func resolvedOptions(_ arguments: [String: LumiJSONValue], mode: String) -> [AskUserOption] {
        switch mode {
        case "yes_no":
            return defaultOptions
        case "free_text":
            return []
        case "choice":
            let parsed = Self.parseOptions(arguments["options"])
            return parsed.isEmpty ? defaultOptions : parsed
        default:
            return defaultOptions
        }
    }

    /// 解析 LLM 传入的 `options` 参数为 `[AskUserOption]`。
    /// 兼容对象（`{label, description?}`）与裸字符串；其他类型被跳过并记录为解析失败。
    /// 返回 nil / 空数组表示没有可用选项（由调用方决定是否回退默认）。
    static func parseOptions(_ value: LumiJSONValue?) -> [AskUserOption] {
        guard case .array(let values) = value else { return [] }
        var result: [AskUserOption] = []
        result.reserveCapacity(values.count)
        for element in values {
            switch element {
            case .object(let dict):
                guard let label = dict.string("label"), !label.isEmpty else { continue }
                result.append(AskUserOption(label: label, description: dict.string("description")))
            case .string(let label):
                if !label.isEmpty { result.append(AskUserOption(label: label)) }
            default:
                // int/double/bool/null 等无法映射为候选项，跳过。
                continue
            }
        }
        return result
    }

    // MARK: - Pending Response Building

    /// 构建 `AskUserPendingResponse`，集中所有字段归一化逻辑。
    static func buildPendingResponse(
        kernel: LumiKernel,
        question: String,
        options: [AskUserOption],
        mode: String
    ) -> AskUserPendingResponse {
        AskUserPendingResponse(
            toolCallId: kernel.toolCallID,
            question: question,
            options: options,
            mode: mode,
            conversationId: kernel.conversationID.uuidString,
            verbosity: kernel.verbosity ?? "standard"
        )
    }

    /// 将 `AskUserPendingResponse` 编码为 pretty-printed JSON 字符串。
    static func encodePendingPayload(_ response: AskUserPendingResponse) throws -> String {
        let data = try jsonEncoder.encode(response)
        return String(decoding: data, as: UTF8.self)
    }

    /// 将 `AskUserErrorResponse` 编码为 JSON 字符串。
    static func encodeErrorPayload(_ response: AskUserErrorResponse) throws -> String {
        let data = try jsonEncoder.encode(response)
        return String(decoding: data, as: UTF8.self)
    }

    // MARK: - Logging

    func logInvocation(question: String, mode: String, options: [AskUserOption]) {
        guard Self.verbose else { return }
        Self.logger.info("\(Self.t) AskUser tool called: \(question) mode=\(mode) options=\(options)")
    }

    static func errorResult(message: String) -> String {
        let error = AskUserErrorResponse(error: message)
        let payload: String
        do {
            payload = try Self.encodeErrorPayload(error)
        } catch {
            payload = "{\"error\":\"Failed to encode ask_user error response\"}"
        }
        return "\(LumiAskUserMarkers.errorPrefix)\n\(payload)"
    }

    // MARK: - Constants

    /// 当用户没有提供 `options` 参数（或提供非法值）时使用的默认选项。
    static let defaultOptions: [AskUserOption] = [AskUserOption(label: "是"), AskUserOption(label: "否")]

    /// `mode` 参数允许的合法值集合。
    static let allowedModes: [String] = ["yes_no", "choice", "free_text"]

    /// 所有 JSON 编解码共享一个 encoder，配置为 pretty-printed 以便人工检查日志。
    private static let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        return encoder
    }()

    // MARK: - Multiple Choice Detection

    /// 检测 question 是否看起来像多选场景。
    /// 当 question 包含选择类关键词时返回 true。
    static func lookLikeMultipleChoice(_ question: String) -> Bool {
        let chineseKeywords = ["哪个", "哪些", "哪一个", "哪一", "选择", "方案", "选项", "模式"]
        let englishKeywords = ["which", "choose", "select", "option", "pick"]

        let lowercased = question.lowercased()
        return chineseKeywords.contains { question.contains($0) }
            || englishKeywords.contains { lowercased.contains($0) }
    }

    /// 检测 question 是否是开放式问题（不能简单用是/否回答）。
    /// 用于拦截 LLM 未传 `allow_free_input` 但问了开放式问题的情况。
    static func lookLikeOpenEnded(_ question: String) -> Bool {
        let chinesePatterns = [
            "怎么办", "做什么", "怎么", "如何", "下一步", "接下来",
            "为什么", "原因", "说明", "解释", "描述", "告诉我",
        ]
        let englishPatterns = [
            "how", "what should", "what do", "what would", "why",
            "explain", "describe", "tell me", "what's", "what is",
        ]

        let lowercased = question.lowercased()
        return chinesePatterns.contains { question.contains($0) }
            || englishPatterns.contains { lowercased.contains($0) }
    }
}
