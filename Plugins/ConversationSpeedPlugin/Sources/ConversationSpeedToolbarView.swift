import LumiKernel
import SwiftUI
import LocalizationKit

struct ConversationSpeedToolbarView: View {
    @ObservedObject var kernel: LumiKernel
    @State private var cachedTPS: Double?
    @State private var hasShownTPSAtLeastOnce = false
    @State private var popoverShown = false

    // Detail data shown inside the popover.
    @State private var modelName: String?
    @State private var outputTokens: Int?
    @State private var streamingDurationMs: Double?
    @State private var timeToFirstTokenMs: Double?
    @State private var providerID: String?

    private var selectedConversationID: UUID? {
        kernel.conversations?.selectedConversationID
    }

    var body: some View {
        Group {
            // Only show if we've seen a valid TPS at least once AND still have a cached value
            if hasShownTPSAtLeastOnce, let tps = cachedTPS {
                Button {
                    popoverShown.toggle()
                } label: {
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
                    .background(Color.orange.opacity(0.22), in: RoundedRectangle(cornerRadius: ToolbarMetrics.chipCornerRadius, style: .continuous))
                }
                .buttonStyle(.plain)
                .help(LumiPluginLocalization.string("Streaming speed help", bundle: .module))
                .popover(isPresented: $popoverShown, arrowEdge: .bottom) {
                    ConversationSpeedPopover(
                        tps: tps,
                        modelName: modelName,
                        outputTokens: outputTokens,
                        streamingDurationMs: streamingDurationMs,
                        timeToFirstTokenMs: timeToFirstTokenMs,
                        providerID: providerID
                    )
                    .frame(width: 300)
                }
            } else {
                EmptyView()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .lumiMessagesDidChange)) { _ in
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

        // Capture detail data for the popover.
        modelName = lastMessage.modelName
        outputTokens = lastMessage.outputTokenCount
        streamingDurationMs = lastMessage.streamingDurationMs
        timeToFirstTokenMs = lastMessage.timeToFirstTokenMs
        providerID = lastMessage.providerID

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

// MARK: - Popover

private struct ConversationSpeedPopover: View {
    let tps: Double
    let modelName: String?
    let outputTokens: Int?
    let streamingDurationMs: Double?
    let timeToFirstTokenMs: Double?
    let providerID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                    .font(.system(size: 18))
                    .foregroundStyle(.orange)
                Text(LumiPluginLocalization.string("Streaming Speed", bundle: .module))
                    .font(.headline)
                Spacer()
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%.1f", tps))
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                Text(LumiPluginLocalization.string("tokens / second", bundle: .module))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text(LumiPluginLocalization.string("Streaming speed description", bundle: .module))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                if let modelName, !modelName.isEmpty {
                    detailRow(
                        LumiPluginLocalization.string("Model", bundle: .module),
                        value: modelName
                    )
                }
                if let outputTokens {
                    detailRow(
                        LumiPluginLocalization.string("Output tokens", bundle: .module),
                        value: "\(outputTokens)"
                    )
                }
                if let streamingDurationMs {
                    detailRow(
                        LumiPluginLocalization.string("Streaming duration", bundle: .module),
                        value: formatDuration(streamingDurationMs)
                    )
                }
                if let timeToFirstTokenMs {
                    detailRow(
                        LumiPluginLocalization.string("Time to first token", bundle: .module),
                        value: formatDuration(timeToFirstTokenMs)
                    )
                }
                if let providerID, !providerID.isEmpty {
                    detailRow(
                        LumiPluginLocalization.string("Provider", bundle: .module),
                        value: providerID
                    )
                }
            }

            Spacer(minLength: 0)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func detailRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }

    private func formatDuration(_ ms: Double) -> String {
        if ms >= 1000 {
            return String(format: "%.2f s", ms / 1000.0)
        }
        return String(format: "%.0f ms", ms)
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
