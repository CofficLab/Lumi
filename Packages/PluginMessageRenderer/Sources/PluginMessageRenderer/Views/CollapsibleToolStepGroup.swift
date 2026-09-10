import os
import KitAgentTool
import KernelCore
import LumiUI
import ProviderConversation
import ProviderMessage
import ProviderToolManager
import SwiftUI

/// V1 (brief) 模式下的默认工具调用行列表。
///
/// 多个工具调用直接逐行显示，不使用汇总文案或折叠/展开交互。
///
/// 与 V2/V3 使用相同的 `ToolCallRowView` 渲染（含耗时、参数/结果按钮、卡片样式），
/// 唯一区别是 V1 不走自定义 ToolCall renderer，统一走默认卡片路径。
struct CollapsibleToolStepGroup: View {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.message-renderer", category: "CollapsibleToolStepGroup")

    let kernel: KernelCoreContainer

    let message: Message
    let toolCalls: [MessageToolCall]
    let verbosity: ResponseVerbosity

    @State private var parameterPopoverToolCallID: String?
    @State private var resultPopoverToolCallID: String?
    @State private var resolvedToolCalls: [MessageToolCall]?

    init(
        kernel: KernelCoreContainer,
        message: Message,
        toolCalls: [MessageToolCall],
        verbosity: ResponseVerbosity
    ) {
        self.kernel = kernel
        self.message = message
        self.toolCalls = toolCalls
        self.verbosity = verbosity
    }

    private var displayedToolCalls: [MessageToolCall] {
        resolvedToolCalls ?? toolCalls
    }

    private var resolutionTaskID: String {
        toolCalls
            .map { "\($0.id):\($0.result != nil)" }
            .joined(separator: "|")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(displayedToolCalls) { toolCall in
                toolCallRow(for: toolCall)
            }
        }
        .task(id: resolutionTaskID) {
            await resolveResults()
        }
    }

    @MainActor
    private func resolveResults() async {
        guard resolvedToolCalls == nil, let manager = kernel.resolveProvider((any ToolManagerProviding).self) else {
            Self.logger.error("Failed to resolve ToolManagerProviding from kernel")
            return
        }

        // 命中"完全解析"缓存时跳过逐个 kernel 查询与 loading 态闪烁
        if let cached = ToolCallResolutionCache.shared.resolvedCalls(
            messageID: message.id,
            toolCalls: toolCalls
        ) {
            resolvedToolCalls = cached
            return
        }

        var resolved = toolCalls
        var didResolveAnyResult = false
        for index in resolved.indices where resolved[index].result == nil {
            if let raw = await manager.toolCallResult(
                for: resolved[index].id,
                conversationID: message.conversationID,
                turnID: message.turnID
            ),
               let converted = MessageToolResult(toolCallResult: raw) {
                resolved[index].result = converted
                didResolveAnyResult = true
            }
        }
        ToolCallResolutionCache.shared.storeIfFullyResolved(
            messageID: message.id,
            toolCalls: resolved
        )
        if didResolveAnyResult || resolved.allSatisfy({ $0.result != nil }) {
            resolvedToolCalls = resolved
        }
    }

    // MARK: - Tool rows

    private func toolCallRow(for toolCall: MessageToolCall) -> some View {
        ToolCallRowView(
            kernel: kernel,
            message: message,
            toolCall: toolCall,
            verbosity: verbosity,
            showsDetails: true,
            parameterPopoverToolCallID: $parameterPopoverToolCallID,
            resultPopoverToolCallID: $resultPopoverToolCallID
        )
    }
}
