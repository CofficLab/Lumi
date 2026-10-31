import Foundation
import Testing
import KitAgentTool
import KitLLM

@testable import PluginAskUser

/// `AskUserTool` 参数解析与 payload 契约的单元测试。
///
/// 这里覆盖的是「模型传来的任意 JSON 参数」到「挂起 payload」这段纯逻辑：
/// 它是 LLM 与 UI 之间唯一的契约面，且输入完全由模型决定（可能缺字段、
/// 类型错误、夹带多余 options），因此边界必须逐条锁住。
@Suite("AskUserTool 参数解析")
struct AskUserToolArgumentTests {

    // MARK: - mode 校验

    @Test("合法 mode 原样返回")
    func validModes() {
        for mode in ["yes_no", "choice", "free_text"] {
            #expect(AskUserTool.resolvedMode(["mode": ToolArgument(mode)]) == mode)
        }
    }

    @Test("缺失或非法 mode 返回 nil（触发必填错误）")
    func invalidModes() {
        #expect(AskUserTool.resolvedMode([:]) == nil)
        #expect(AskUserTool.resolvedMode(["question": ToolArgument("hi")]) == nil)
        // 未知取值
        #expect(AskUserTool.resolvedMode(["mode": ToolArgument("maybe")]) == nil)
        // 大小写敏感：模型传 "YES_NO" 应被拒绝，而不是被静默纠正。
        #expect(AskUserTool.resolvedMode(["mode": ToolArgument("YES_NO")]) == nil)
        // 非字符串类型
        #expect(AskUserTool.resolvedMode(["mode": ToolArgument(1)]) == nil)
    }

    // MARK: - options 按 mode 解析

    @Test("yes_no 忽略传入的 options，固定返回是/否")
    func yesNoIgnoresOptions() {
        let options = AskUserTool.resolvedOptions(
            ["options": ToolArgument(["Custom", "Other"])],
            mode: "yes_no"
        )
        #expect(options.map(\.label) == ["是", "否"])
        #expect(options.allSatisfy { $0.description == nil && $0.badge == nil })
    }

    @Test("free_text 返回空选项")
    func freeTextHasNoOptions() {
        #expect(AskUserTool.resolvedOptions(["options": ToolArgument(["A"])], mode: "free_text").isEmpty)
        #expect(AskUserTool.resolvedOptions([:], mode: "free_text").isEmpty)
    }

    @Test("choice 解析对象与裸字符串混合数组")
    func choiceParsesMixedOptions() {
        let options = AskUserTool.resolvedOptions(
            ["options": ToolArgument([
                "Debug",
                ["label": "Release", "description": "正式发布", "badge": "推荐"],
                ["label": "Profile"],
            ])],
            mode: "choice"
        )
        #expect(options.map(\.label) == ["Debug", "Release", "Profile"])
        #expect(options[0].description == nil)
        #expect(options[1].description == "正式发布")
        #expect(options[1].badge == "推荐")
        #expect(options[2].description == nil)
    }

    @Test("choice 兼容 label 缺失时的回退字段")
    func choiceOptionLabelFallbacks() {
        let options = AskUserTool.parseOptions([
            ["description": "只有 description"],
            ["value": "只有 value"],
            ["text": "只有 text"],
        ])
        #expect(options.map(\.label) == ["只有 description", "只有 value", "只有 text"])
    }

    @Test("无法取出标签的项被丢弃；空字符串标签同样丢弃")
    func choiceDropsUnusableOptions() {
        let options = AskUserTool.parseOptions([
            ["label": ""],
            ["badge": "只有徽标"],
            ["description": ""],
            "Debug",
        ])
        // 只有 label 非空的裸字符串与合法对象保留。
        #expect(options.map(\.label) == ["Debug"])
    }

    @Test("纯空白标签不被丢弃（原样保留）")
    func choiceKeepsWhitespaceLabel() {
        // 现状：`parseOptions` 只判 `isEmpty`，不 trim。模型传出 `"   "` 时
        // 会渲染出一个空按钮。这里锁住当前行为，避免有人误以为已做清洗；
        // 若将来在 parseOptions 或 UI 侧补 trim，这条断言会失败并提醒同步。
        let options = AskUserTool.parseOptions([["label": "   "]])
        #expect(options.map(\.label) == ["   "])
        #expect(options.count == 1)
    }

    @Test("非数组的 options 返回空（由上层报 choice 缺选项错误）")
    func choiceRejectsNonArray() {
        #expect(AskUserTool.parseOptions("Debug").isEmpty)
        #expect(AskUserTool.parseOptions(["label": "单对象"]).isEmpty)
        #expect(AskUserTool.parseOptions(nil).isEmpty)
    }

    @Test("choice 传入空数组时返回空，由上层拦截")
    func choiceEmptyArray() {
        #expect(AskUserTool.parseOptions([Any]()).isEmpty)
    }

    // MARK: - badge 归一化

    @Test("badge 归一化：压缩空白、丢弃空值、截断到 16 字符")
    func badgeNormalization() {
        #expect(AskUserOption(label: "A", badge: "  推荐\n ").badge == "推荐")
        #expect(AskUserOption(label: "A", badge: "多  空格   分隔").badge == "多 空格 分隔")
        #expect(AskUserOption(label: "A", badge: "   ").badge == nil)
        #expect(AskUserOption(label: "A", badge: "").badge == nil)
        #expect(AskUserOption(label: "A", badge: nil).badge == nil)

        let long = String(repeating: "x", count: 40)
        #expect(AskUserOption(label: "A", badge: long).badge == String(repeating: "x", count: 16))
    }

    // MARK: - 空问题

    @Test("空问题、纯空白问题、缺失问题均返回错误且不挂起")
    func rejectsEmptyQuestion() async throws {
        let tool = AskUserTool()

        for arguments in [
            [String: ToolArgument](),
            ["question": ToolArgument(""), "mode": ToolArgument("yes_no")],
            ["question": ToolArgument("   \n "), "mode": ToolArgument("yes_no")],
            ["question": ToolArgument(42), "mode": ToolArgument("yes_no")],
        ] {
            let result = try await tool.executeResult(arguments: arguments)
            #expect(result.isError, "空问题应报错：\(arguments)")
            #expect(!result.awaitingUserResponse, "空问题不应挂起回合")
            #expect(result.content.hasPrefix("❌"))
        }
    }

    // MARK: - 执行结果的挂起语义

    @Test("错误结果带 ❌ 前缀以便 AgentLoop 与日志区分")
    func errorPrefix() {
        #expect(AskUserTool.errorResult(message: "boom").hasPrefix("❌"))
        #expect(AskUserTool.errorResult(message: "boom").contains("boom"))
    }

    @Test("合法调用返回 awaitingUserResponse 且 interactionState 为 waiting")
    func successfulResultSuspends() async throws {
        let result = try await AskUserTool().executeResult(arguments: [
            "question": ToolArgument("继续吗?"),
            "mode": ToolArgument("yes_no"),
        ])
        #expect(result.awaitingUserResponse)
        #expect(!result.isError)
        #expect(result.interactionState == .waiting)
        #expect(result.images.isEmpty)
    }

    @Test("三种模式的 payload 都能被解码回完整响应")
    func payloadRoundTrips() async throws {
        let cases: [(String, [String: ToolArgument])] = [
            ("yes_no", ["question": ToolArgument("继续?"), "mode": ToolArgument("yes_no")]),
            ("free_text", ["question": ToolArgument("怎么做?"), "mode": ToolArgument("free_text")]),
            (
                "choice",
                [
                    "question": ToolArgument("选哪个?"),
                    "mode": ToolArgument("choice"),
                    "options": ToolArgument(["Debug", ["label": "Release", "badge": "推荐"]]),
                ]
            ),
        ]

        for (expectedMode, arguments) in cases {
            let result = try await AskUserTool().executeResult(arguments: arguments)
            let payload = try #require(result.content.data(using: .utf8))
            let response = try JSONDecoder().decode(AskUserPendingResponse.self, from: payload)

            #expect(response.mode == expectedMode)
            #expect(!response.question.isEmpty)
            #expect(response.toolCallId == AskUserTool.toolName)
            // verbosity 固定为 standard：UI 层按它决定是否在消息正文内嵌交互。
            #expect(response.verbosity == "standard")
            // conversationId 故意留空：真实会话由 suspension 携带，不由工具决定。
            #expect(response.conversationId.isEmpty)
        }
    }

    // MARK: - schema

    @Test("schema 声明 question/mode 必填，options 仅在 choice 下有意义")
    func schemaContract() throws {
        let schema = AskUserTool().inputSchema(for: .english)
        #expect((schema["required"] as? [String]) == ["question", "mode"])

        let properties = try #require(schema["properties"] as? [String: Any])
        let mode = try #require(properties["mode"] as? [String: Any])
        let enumValues = try #require(mode["enum"] as? [String])
        #expect(Set(enumValues) == ["yes_no", "choice", "free_text"])

        let question = try #require(properties["question"] as? [String: Any])
        #expect(question["type"] as? String == "string")
    }

    @Test("工具身份与调度语义稳定")
    func toolIdentity() {
        let tool = AskUserTool()
        #expect(tool.name == "ask_user")
        #expect(AskUserTool.toolName == "ask_user")
        // interactive：与用户交互，同回合内的后续工具必须串行等待。
        #expect(tool.executionCapability == .interactive)
        // 提问本身不改变外部状态，风险等级为 safe（无需授权弹窗）。
        #expect(tool.permissionRiskLevel(arguments: [:]) == .safe)
    }

    @Test("displayDescription 回显问题文案，缺问题时给出通用文案")
    func displayDescription() {
        #expect(
            AskUserTool().displayDescription(for: ["question": ToolArgument("继续构建?")])
                == "向用户提问：继续构建?"
        )
        #expect(AskUserTool().displayDescription(for: [:]) == "Ask the user")
        #expect(AskUserTool().displayDescription(for: ["question": ToolArgument(" ")]) == "Ask the user")
    }

    @Test("description 明确要求先选 mode 并警告不要滥用 yes_no")
    func descriptionContract() {
        let description = AskUserTool().description(for: .english)
        for keyword in ["mode", "yes_no", "choice", "free_text", "CRITICAL"] {
            #expect(
                description.contains(keyword),
                "工具描述缺少关键指令「\(keyword)」，模型可能不传 mode"
            )
        }
    }
}
