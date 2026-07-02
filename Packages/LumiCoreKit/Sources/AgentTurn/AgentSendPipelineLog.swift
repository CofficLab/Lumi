import Foundation
import os

public enum AgentSendPipelineLog {
    public static let enabled = false
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "agent.send-pipeline")
    public static let t = "[AgentPipeline]"

    public static func conv(_ conversationID: UUID) -> String {
        String(conversationID.uuidString.prefix(8))
    }
}
