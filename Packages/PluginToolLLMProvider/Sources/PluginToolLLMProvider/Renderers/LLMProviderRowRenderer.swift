import Foundation
import KitAgentTool
import ProviderLLMManager
import ProviderMessageRendering
import SwiftUI

/// `add_llm_provider` 工具结果的专用行渲染器。
///
/// 数据流：
/// 1. LLM 调用 `add_llm_provider`，工具返回人类可读正文 + 末尾 JSON 代码块；
/// 2. 本渲染器命中 `canRender`（工具名匹配且载荷能解码），从
///    `ToolCallResult.content` 提取 JSON 并解码为 `LLMProviderProposal`；
/// 3. 渲染「添加供应商」卡片，用户可编辑端点与模型、填入 API Key 并确认；
/// 4. 任何解析失败都回退到默认工具文本视图，不丢信息。
public struct LLMProviderRowRenderer: ToolCallRowRenderer {

    public static let id = "llm-provider-proposal-row"

    /// 高于通用授权卡片（120）：本工具不走授权路径，走自己的确认卡片。
    public static let priority = 130

    private let store: UserDefinedCloudProviderStore?
    private let manager: (any LLMManaging)?

    /// 依赖能力来自共享 Provider 层，故初始化器保持 internal。
    init(
        store: UserDefinedCloudProviderStore? = nil,
        manager: (any LLMManaging)? = nil
    ) {
        self.store = store
        self.manager = manager
    }

    public func canRender(toolCall: ToolCall) -> Bool {
        guard toolCall.name == AddLLMProviderTool.toolName,
              let content = toolCall.result?.content else {
            return false
        }
        return ProviderProposalPayload.decode(from: content) != nil
    }

    @MainActor
    public func render(toolCall: ToolCall, message: ToolCallRowMessageContext) -> AnyView {
        guard let content = toolCall.result?.content,
              let proposal = ProviderProposalPayload.decode(from: content) else {
            // 回退：展示工具返回的原始文本，避免信息丢失。
            return AnyView(
                Text(toolCall.result?.content ?? pluginLocalization.string("Add LLM Provider"))
                    .font(.appCaption)
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
            )
        }

        return AnyView(
            LLMProviderProposalCard(
                proposal: proposal,
                store: store,
                manager: manager
            )
        )
    }
}
