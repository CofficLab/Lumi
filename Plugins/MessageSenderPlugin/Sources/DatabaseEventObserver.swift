import LumiCoreKit
import os
import SuperLogKit
import SwiftUI

struct DatabaseEventObserver<Content: View>: View, SuperLog {
    nonisolated static var emoji: String { "📬" }
    nonisolated static var verbose: Bool { false }
    nonisolated static var logger: Logger { MessageSenderPlugin.logger }

    let senderService: SenderService
    let content: Content

    var body: some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .messageSaved)) { notification in
                guard let conversationId = notification.userInfo?["conversationId"] as? UUID else {
                    Self.logger.error("\(Self.t)Failed to get conversationId from messageSaved: \(String(describing: notification.userInfo))")
                    return
                }
                if Self.verbose {
                    Self.logger.info("\(Self.t)messageSaved")
                }
                senderService.handleMessageSaved(conversationId: conversationId)
            }
            .onReceive(NotificationCenter.default.publisher(for: .agentTurnPhaseChanged)) { notification in
                guard let conversationId = notification.object as? UUID else {
                    Self.logger.error("\(Self.t)Failed to get conversationId from agentTurnPhaseChanged: \(String(describing: notification.object))")
                    return
                }
                guard notification.userInfo?["phase"] as? String == AgentTurnPhase.processing.rawValue else { return }
                if Self.verbose {
                    Self.logger.info("\(Self.t)agentTurnPhaseChanged → processing")
                }
                senderService.handleMessageSaved(conversationId: conversationId)
            }
    }
}
