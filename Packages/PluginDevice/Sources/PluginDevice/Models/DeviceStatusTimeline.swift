import Foundation
import ProviderMessage

/// 构造「设备状态卡片」时间线消息。
///
/// 这些消息只用于把设备指标呈现在聊天消息区，不应进入后续 LLM 上下文。
/// 消息带 `renderKind = "device-status"`，会被 `MessageTimelineEvent.isTimelineEvent`
/// 识别并从 LLM 历史中过滤掉。
///
/// ## 载荷为什么放在 content
///
/// 与磁盘测速卡片同理：`MessageManaging.updateMessage(id:in:content:)`
/// **只能改 content**，改不了已经落库的 metadata。载荷若放在 metadata，
/// 卡片将永远停在插入时的状态。因此载荷放 content，metadata 只保留时间线标记。
enum DeviceStatusTimeline {

    /// 渲染器 ID，与插件注册的 `MessageRendererItem.id` 保持一致。
    static let rendererID = "com.coffic.lumi.plugin.device-info.card"

    /// 构造一条设备状态时间线消息。
    ///
    /// - Parameters:
    ///   - conversationID: 所属会话。
    ///   - turnID: 所属回合（可能为空，例如 ACP 链路）。
    ///   - payload: 状态载荷。
    /// - Returns: 可直接插入消息管理器的时间线消息。
    static func message(
        conversationID: UUID,
        turnID: UUID?,
        payload: DeviceStatusPayload
    ) -> Message {
        Message(
            conversationID: conversationID,
            role: .system,
            content: encode(payload) ?? summaryText(for: payload),
            turnID: turnID,
            metadata: [MessageTimelineEvent.metadataKey: MessageTimelineEvent.deviceStatus],
            renderKind: MessageTimelineEvent.deviceStatusRenderKind,
            preferredRendererID: rendererID
        )
    }

    /// 把载荷编码成 `Message.content` 的字符串。
    ///
    /// 使用 JSON 编码以保证数值精度与可解析性；编码失败时返回 nil，
    /// 由调用方回退到可读摘要。
    static func encode(_ payload: DeviceStatusPayload) -> String? {
        guard let data = try? JSONEncoder().encode(payload) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// 从消息 `content` 还原结构化载荷。
    ///
    /// 载荷缺失或损坏时返回 nil，渲染器应回退到纯文本展示。
    static func decodePayload(from content: String) -> DeviceStatusPayload? {
        guard let data = content.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(DeviceStatusPayload.self, from: data)
    }

    /// 消息正文的可读摘要。
    ///
    /// 只在 JSON 编码失败时使用，确保渲染器缺席时用户仍能看懂这条消息。
    static func summaryText(for payload: DeviceStatusPayload) -> String {
        var lines: [String] = ["Device status (\(payload.scope.rawValue))"]
        if let cpu = payload.cpu {
            lines.append("CPU: \(Int(cpu.usagePercentage.rounded()))%")
        }
        if let memory = payload.memory {
            lines.append("Memory: \(Int(memory.usagePercentage.rounded()))%")
        }
        if let gpu = payload.gpu {
            lines.append("GPU: \(Int(gpu.utilizationPercentage.rounded()))%")
        }
        if let battery = payload.battery, battery.hasBattery {
            lines.append("Battery: \(Int((battery.level * 100).rounded()))%")
        }
        return lines.joined(separator: " · ")
    }
}
