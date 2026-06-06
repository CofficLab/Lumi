import Foundation
import SuperLogKit
import os

/// Agent 消息发送链路专用日志。
///
/// Console 过滤：
/// `subsystem == "com.coffic.lumi" AND category == "agent.send-pipeline"`
public enum AgentSendPipelineLog: SuperLog {
    public nonisolated static let emoji = "🛤️"

    /// 设为 `false` 可关闭整条链路日志。
    nonisolated(unsafe) public static var enabled: Bool = true

    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "agent.send-pipeline")

    public static func conv(_ conversationId: UUID) -> String {
        String(conversationId.uuidString.prefix(8))
    }
}
