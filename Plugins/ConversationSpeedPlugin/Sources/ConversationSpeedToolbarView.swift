import LumiKernel
import SwiftUI

struct ConversationSpeedToolbarView: View {
    @ObservedObject var kernel: LumiKernel
    @State private var cachedTPS: Double?
    @State private var hasShownTPSAtLeastOnce = false

    private var selectedConversationID: UUID? {
        kernel.conversations?.selectedConversationID
    }

    var body: some View {
        Group {
            // Only show if we've seen a valid TPS at least once AND still have a cached value
            if hasShownTPSAtLeastOnce, let tps = cachedTPS {
                HStack(spacing: ToolbarMetrics.chipSpacing) {
                    Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                        .font(.system(size: ToolbarMetrics.chipIconSize, weight: .medium))
                    Text(String(format: "%.1f tok/s", tps))
                        .font(.system(size: ToolbarMetrics.chipTextSize, weight: ToolbarMetrics.chipTextWeight))
                        .contentTransition(.numericText())
                }
                .foregroundColor(.orange)
                .padding(.horizontal, ToolbarMetrics.chipHorizontalPadding)
                .padding(.vertical, ToolbarMetrics.chipVerticalPadding)
                .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: ToolbarMetrics.chipCornerRadius, style: .continuous))
                .help("Streaming speed: \(String(format: "%.1f", tps)) tokens/second")
            } else {
                EmptyView()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("com.coffic.lumi.messagesDidChange"))) { _ in
            self.updateTPS()
        }
        .onAppear {
            self.updateTPS()
        }
    }

    private func updateTPS() {
        guard let conversationID = selectedConversationID else {
            if ConversationSpeedPlugin.verbose {
                ConversationSpeedPlugin.logger.info("\(ConversationSpeedPlugin.t)No selected conversation ID")
            }
            return
        }

        guard let lastMessage = kernel.messageManager?.lastMessage(in: conversationID) else {
            if ConversationSpeedPlugin.verbose {
                ConversationSpeedPlugin.logger.info("\(ConversationSpeedPlugin.t)No last message for conversation \(conversationID.uuidString.prefix(8))")
            }
            return
        }

        // Try tokensPerSecond property first
        if let tps = lastMessage.tokensPerSecond {
            if ConversationSpeedPlugin.verbose {
                ConversationSpeedPlugin.logger.info("\(ConversationSpeedPlugin.t)tokensPerSecond from property: \(tps)")
            }
            cachedTPS = tps
            hasShownTPSAtLeastOnce = true
            return
        }

        // Fallback: calculate from metadata
        if let outputTokensStr = lastMessage.metadata["outputTokens"],
           let streamingDurationStr = lastMessage.metadata["streamingDurationMs"],
           let outputTokens = Int(outputTokensStr),
           let streamingDurationMs = Double(streamingDurationStr),
           streamingDurationMs > 0 {
            let tps = Double(outputTokens) / (streamingDurationMs / 1000.0)
            if ConversationSpeedPlugin.verbose {
                ConversationSpeedPlugin.logger.info("\(ConversationSpeedPlugin.t)Calculated TPS from metadata: \(tps) (outputTokens=\(outputTokens), duration=\(streamingDurationMs)ms)")
            }
            cachedTPS = tps
            hasShownTPSAtLeastOnce = true
        } else {
            // Don't clear cachedTPS if we've already shown it once
            // This handles cases where subsequent messages (like tool results) don't have TPS data
            if !hasShownTPSAtLeastOnce {
                if ConversationSpeedPlugin.verbose {
                    ConversationSpeedPlugin.logger.info("\(ConversationSpeedPlugin.t)Cannot calculate TPS (no cached value)")
                }
                cachedTPS = nil
            } else {
                if ConversationSpeedPlugin.verbose {
                    ConversationSpeedPlugin.logger.info("\(ConversationSpeedPlugin.t)Keeping cached TPS=\(cachedTPS ?? 0)")
                }
            }
        }
    }
}

enum ToolbarMetrics {
    static let chipIconSize: CGFloat = 10
    static let chipTextSize: CGFloat = 10
    static let chipTextWeight: Font.Weight = .medium
    static let chipSpacing: CGFloat = 3
    static let chipHorizontalPadding: CGFloat = 6
    static let chipVerticalPadding: CGFloat = 3
    static let chipCornerRadius: CGFloat = 5
}
