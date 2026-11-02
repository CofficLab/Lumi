import Foundation
import ProviderMessage

/// 构造「用户切换模型」时间线消息的辅助工具。
///
/// 消息带有时间线事件元数据，由 `core-model-switched` 渲染器展示，
/// 且不进入 LLM 上下文（`MessageTimelineEvent.isTimelineEvent` 会过滤它）。
///
/// 消息正文给出一句可读摘要，结构化数据（旧/新供应商与模型）放在 metadata 里，
/// 这样即使自定义渲染器被禁用，正文依然能表达「切换到了哪个模型」。
enum ModelSwitchTimeline {
    /// 渲染器 ID，与插件注册的 `MessageRendererItem.id` 保持一致。
    static let rendererID = "core-model-switched"

    /// 构造一条模型切换时间线消息。
    ///
    /// - Parameters:
    ///   - conversationID: 所属会话。
    ///   - fromProviderID: 切换前的供应商 ID（首次选择时为 nil）。
    ///   - fromModelName: 切换前的模型名（首次选择时为 nil）。
    ///   - toProviderID: 切换后的供应商 ID。
    ///   - toModelName: 切换后的模型名。
    /// - Returns: 可直接插入消息管理器的时间线消息。
    static func message(
        conversationID: UUID,
        fromProviderID: String?,
        fromModelName: String?,
        toProviderID: String?,
        toModelName: String?
    ) -> Message {
        var metadata: [String: String] = [
            MessageTimelineEvent.metadataKey: MessageTimelineEvent.modelSwitched,
        ]
        if let fromProviderID, !fromProviderID.isEmpty {
            metadata[MessageTimelineEvent.modelSwitchedFromProviderIDKey] = fromProviderID
        }
        if let fromModelName, !fromModelName.isEmpty {
            metadata[MessageTimelineEvent.modelSwitchedFromModelNameKey] = fromModelName
        }
        if let toProviderID, !toProviderID.isEmpty {
            metadata[MessageTimelineEvent.modelSwitchedToProviderIDKey] = toProviderID
        }
        if let toModelName, !toModelName.isEmpty {
            metadata[MessageTimelineEvent.modelSwitchedToModelNameKey] = toModelName
        }

        return Message(
            conversationID: conversationID,
            role: .system,
            content: summaryText(
                fromProviderID: fromProviderID,
                fromModelName: fromModelName,
                toProviderID: toProviderID,
                toModelName: toModelName
            ),
            metadata: metadata,
            renderKind: MessageTimelineEvent.modelSwitchedRenderKind,
            preferredRendererID: rendererID
        )
    }

    /// 消息正文的可读摘要。
    ///
    /// 没有「切换前」时（首次为会话选定模型）只说「已切换到」，
    /// 不编造一个并不存在的旧模型。
    static func summaryText(
        fromProviderID: String?,
        fromModelName: String?,
        toProviderID: String?,
        toModelName: String?
    ) -> String {
        let target = displayName(providerID: toProviderID, modelName: toModelName) ?? "未知模型"
        guard let source = displayName(providerID: fromProviderID, modelName: fromModelName) else {
            return "已切换到 \(target)"
        }
        return "已从 \(source) 切换到 \(target)"
    }

    /// 把「供应商 + 模型」拼成一行可读文本。
    ///
    /// 只有供应商没有模型时只显示供应商；两者都没有时返回 nil。
    private static func displayName(providerID: String?, modelName: String?) -> String? {
        let provider = providerID?.trimmingCharacters(in: .whitespacesAndNewlines)
        let model = modelName?.trimmingCharacters(in: .whitespacesAndNewlines)
        switch (provider?.isEmpty == false ? provider : nil, model?.isEmpty == false ? model : nil) {
        case let (provider?, model?):
            return "\(provider) · \(model)"
        case let (provider?, nil):
            return provider
        case let (nil, model?):
            return model
        case (nil, nil):
            return nil
        }
    }
}
