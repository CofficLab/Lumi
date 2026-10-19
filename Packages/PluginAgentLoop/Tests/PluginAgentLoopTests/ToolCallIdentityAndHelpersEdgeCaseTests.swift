import Foundation
import KitLLM
import ProviderMessage
import Testing
@testable import PluginAgentLoop

/// `ToolCallIdentityNormalizer.ids(in:)` 与 `Helpers` 中几处只在特定输入下
/// 才会走到的分支：此前用例都传空历史或走主路径，这些分支从未被执行。
@Suite("Tool 调用身份归一化的边界分支")
struct ToolCallIdentityNormalizationEdgeCaseTests {

    // MARK: - ids(in:)

    /// `ids(in:)` 之前只在空历史下被调用，reduce 闭包从未真正收集过 ID。
    /// 供应商复用计数器的场景依赖这里返回历史里已占用的全部 ID。
    @Test("ids(in:) 收集 assistant 工具调用与 tool 结果的 ID")
    func idsCollectsToolCallIDsFromBothRoles() {
        let messages = [
            LLMMessage(
                role: .assistant,
                content: "",
                toolCalls: [
                    LLMToolCall(id: "call_a", name: "ls", arguments: "{}"),
                    LLMToolCall(id: "call_b", name: "read_file", arguments: "{}")
                ]
            ),
            LLMMessage(role: .tool, content: "ok", toolCallID: "call_a")
        ]

        let ids = ToolCallIdentityNormalizer.ids(in: messages)

        #expect(ids == ["call_a", "call_b"])
    }

    /// 空字符串的 toolCallID 不应占用 ID——否则归一化会把供应商的正常 ID
    /// 误判为已占用，白白替换掉可用的 ID。
    @Test("ids(in:) 忽略空字符串 toolCallID")
    func idsIgnoresEmptyToolCallID() {
        let messages = [
            LLMMessage(role: .tool, content: "ok", toolCallID: ""),
            LLMMessage(role: .tool, content: "ok", toolCallID: "real_id")
        ]

        let ids = ToolCallIdentityNormalizer.ids(in: messages)

        #expect(ids == ["real_id"])
    }

    /// `toolCalls` 为 nil 时不能崩溃，且不得贡献任何 ID。
    @Test("ids(in:) 容忍没有工具调用的消息")
    func idsToleratesMessagesWithoutToolCalls() {
        let messages = [
            LLMMessage(role: .user, content: "你好"),
            LLMMessage(role: .assistant, content: "在", toolCalls: nil)
        ]

        let ids = ToolCallIdentityNormalizer.ids(in: messages)

        #expect(ids.isEmpty)
    }

    // MARK: - normalize

    /// 供应商返回纯空白 ID 时必须替换：归一化前先 trim，
    /// trim 后为空则走 makeUniqueID。
    @Test("空白工具调用 ID 会被替换为生成的唯一 ID")
    func normalizeReplacesWhitespaceOnlyID() {
        let normalized = ToolCallIdentityNormalizer.normalize(
            LLMResponse(
                content: "",
                toolCalls: [
                    LLMToolCall(id: "   ", name: "ls", arguments: "{}"),
                    LLMToolCall(id: "keep_me", name: "read_file", arguments: "{}")
                ]
            ),
            avoiding: []
        )

        let toolCalls = normalized.toolCalls ?? []
        #expect(toolCalls[0].id.hasPrefix("call_lumi_"))
        #expect(toolCalls[0].id != "   ")
        // 未冲突的 ID 必须原样保留，不能被无谓替换。
        #expect(toolCalls[1].id == "keep_me")
    }

    /// ID 前后带空白但内容有效：trim 后不应被误判为冲突而替换，
    /// 归一化后的 ID 必须是 trim 后的干净值。
    @Test("带前后空白的有效 ID 归一化为 trim 后的值")
    func normalizeTrimsSurroundingWhitespaceOfValidID() {
        let normalized = ToolCallIdentityNormalizer.normalize(
            LLMResponse(
                content: "",
                toolCalls: [LLMToolCall(id: "  spaced_id  ", name: "ls", arguments: "{}")]
            ),
            avoiding: []
        )

        let toolCalls = normalized.toolCalls ?? []
        #expect(toolCalls[0].id == "spaced_id")
    }

    /// 已占用的、带空白的 ID 必须在 trim 后正确判定为冲突。
    @Test("归一化按 trim 后的 ID 判定冲突")
    func normalizeDetectsCollisionAfterTrim() {
        let normalized = ToolCallIdentityNormalizer.normalize(
            LLMResponse(
                content: "",
                toolCalls: [LLMToolCall(id: "  taken  ", name: "ls", arguments: "{}")]
            ),
            avoiding: ["taken"]
        )

        let toolCalls = normalized.toolCalls ?? []
        #expect(toolCalls[0].id != "taken")
        #expect(toolCalls[0].id.hasPrefix("call_lumi_"))
    }

    /// 空 toolCalls 数组与 nil 都应原样返回，避免无谓重建响应。
    @Test("没有工具调用时归一化原样返回响应")
    func normalizeReturnsResponseUnchangedWithoutToolCalls() {
        let responseWithNil = LLMResponse(content: "直接回答", model: "kimi-k3")
        #expect(ToolCallIdentityNormalizer.normalize(responseWithNil, avoiding: ["x"]).toolCalls == nil)

        let responseWithEmpty = LLMResponse(content: "直接回答", model: "kimi-k3", toolCalls: [])
        let normalized = ToolCallIdentityNormalizer.normalize(responseWithEmpty, avoiding: ["x"])
        #expect((normalized.toolCalls ?? []).isEmpty)
        #expect(normalized.content == "直接回答")
    }
}

// MARK: - Helpers 边界分支

@Suite("消息与 LLM 消息互转的边界分支")
struct MessageConversionEdgeCaseTests {

    /// assistant 工具调用没有 result 时跳过图片收集：
    /// 否则 nil 会被当成「无图」而错误地登记一条空 pending。
    @Test("没有结果的 assistant 工具调用不参与图片收集")
    func llmMessagesSkipsToolCallsWithoutResult() {
        let conversationID = UUID()
        let imageData = Data([0x89, 0x50, 0x4E, 0x47])
        let assistant = Message(
            conversationID: conversationID,
            role: .assistant,
            content: "",
            toolCalls: [
                // 无 result 的工具调用：不应崩溃，也不应登记空图片。
                MessageToolCall(id: "pending", name: "run_command", arguments: "{}"),
                MessageToolCall(
                    id: "with_image",
                    name: "read_image",
                    arguments: "{}",
                    result: MessageToolResult(
                        content: "图",
                        imageAttachments: [
                            MessageImageAttachment(data: imageData.base64EncodedString(), mimeType: "image/png")
                        ]
                    )
                )
            ]
        )
        let tool = Message(conversationID: conversationID, role: .tool, content: "图", toolCallID: "with_image")

        let messages = llmMessages(from: [assistant, tool])

        #expect(messages[0].role == .assistant)
        #expect(messages[0].images.isEmpty)
        // 只有带 result 的那次调用把图片挂到了 tool 消息上。
        #expect(messages[1].role == .tool)
        #expect(messages[1].images == [MessageImage(data: imageData, mimeType: "image/png")])
    }

    /// assistant 消息可能没有工具调用（如纯文本回复）：
    /// 图片收集循环必须容忍 nil，而不是崩溃。
    @Test("没有工具调用的 assistant 消息跳过图片收集")
    func llmMessagesSkipsAssistantWithoutToolCalls() {
        let conversationID = UUID()
        let assistant = Message(conversationID: conversationID, role: .assistant, content: "纯文本回复", toolCalls: nil)

        let messages = llmMessages(from: [assistant])

        #expect(messages.count == 1)
        #expect(messages[0].role == .assistant)
        #expect(messages[0].images.isEmpty)
        #expect(messages[0].content == "纯文本回复")
    }

    /// KitLLM 的 `.unknown` 在 ProviderMessage 中没有对应 case，
    /// 必须回落到 `.system` 而不是崩溃。
    @Test("未知 LLM 角色恢复为消息时回落到 system")
    func messageFromLLMMessageFallsBackToSystemForUnknownRole() {
        let message = LLMMessage(role: .unknown, content: "陌生角色")

        let restored = messageFromLLMMessage(message, conversationID: UUID())

        #expect(restored.role == .system)
        #expect(restored.content == "陌生角色")
    }

    /// 合法角色必须原样保留，不能被 `.system` 回落规则误伤。
    @Test("合法 LLM 角色原样保留")
    func messageFromLLMMessagePreservesKnownRoles() {
        for role in [KitLLM.MessageRole.tool, .error, .status, .assistant, .user, .system] {
            let restored = messageFromLLMMessage(
                LLMMessage(role: role, content: "c"),
                conversationID: UUID()
            )
            #expect(restored.role.rawValue == role.rawValue)
        }
    }

    /// 只有 user 角色的图片会写回附件 metadata；
    /// 非 user 角色不应凭空生成 metadata。
    @Test("非 user 角色的图片不会写回附件 metadata")
    func messageFromLLMMessageSkipsMetadataForNonUserRole() {
        let image = MessageImage(data: Data([0x89, 0x50]), mimeType: "image/png")

        let assistant = messageFromLLMMessage(
            LLMMessage(role: .assistant, content: "含图", images: [image]),
            conversationID: UUID()
        )
        let user = messageFromLLMMessage(
            LLMMessage(role: .user, content: "含图", images: [image]),
            conversationID: UUID()
        )

        #expect(assistant.metadata.isEmpty)
        #expect(!user.metadata.isEmpty)
        // 无论哪种角色，图片都不落到 LLM 正文的 images 上（正文保持纯文本）。
        #expect(user.content == "含图")
    }

    /// 非法 base64 的附件在转换时应被丢弃，而不是让整个请求失败。
    @Test("非法 base64 的图片附件被安全丢弃")
    func llmMessageDropsInvalidBase64ImageAttachments() {
        let message = Message(
            conversationID: UUID(),
            role: .user,
            content: "这张图",
            metadata: UserAttachmentMetadata.encodeImageAttachments([
                UserImageAttachment(mimeType: "image/png", base64Data: "!!!not-base64!!!", fileName: "broken.png")
            ])
        )

        let llmMessage = message.llmMessage

        #expect(llmMessage.images.isEmpty)
        // 正文仍应正常携带，不因附件损坏而丢失。
        #expect(llmMessage.content == "这张图")
    }

    /// tool 消息没有 toolCallID 时不能误挂图片（无可匹配的 pending）。
    @Test("没有 toolCallID 的 tool 消息不会获得图片")
    func llmMessageToolWithoutToolCallIDGetsNoImages() {
        let conversationID = UUID()
        let imageData = Data([0x89, 0x50, 0x4E, 0x47])
        let assistant = Message(
            conversationID: conversationID,
            role: .assistant,
            content: "",
            toolCalls: [
                MessageToolCall(
                    id: "call_x",
                    name: "read_image",
                    arguments: "{}",
                    result: MessageToolResult(
                        content: "图",
                        imageAttachments: [
                            MessageImageAttachment(data: imageData.base64EncodedString(), mimeType: "image/png")
                        ]
                    )
                )
            ]
        )
        // 故意不设置 toolCallID，与 assistant 的调用无法配对。
        let orphanTool = Message(conversationID: conversationID, role: .tool, content: "图")

        let messages = llmMessages(from: [assistant, orphanTool])

        #expect(messages[1].role == .tool)
        #expect(messages[1].images.isEmpty)
    }
}
