import LumiCoreKit
import LumiCoreKit
import LumiUI
import SwiftUI

struct CurrentModelTPSToolbarView: View {
    @LumiTheme private var theme
    @ObservedObject private var chatService: ChatService
    @State private var currentStat: ModelPerformanceStats?

    init(chatService: any LumiChatServicing) {
        guard let chatService = chatService as? ChatService else {
            preconditionFailure("CurrentModelTPSToolbarView requires ChatService")
        }
        _chatService = ObservedObject(wrappedValue: chatService)
    }

    var body: some View {
        Group {
            if let currentStat, currentStat.avgTPS > 0 {
                HStack(spacing: ToolbarMetrics.chipSpacing) {
                    Image(systemName: "speedometer")
                        .font(.system(size: ToolbarMetrics.chipIconSize, weight: ToolbarMetrics.iconWeight))

                    Text(ModelSelectorFormatService.tps(currentStat.avgTPS))
                        .font(.system(size: ToolbarMetrics.chipTextSize, weight: ToolbarMetrics.chipTextWeight))
                        .monospacedDigit()
                }
                .foregroundColor(theme.info)
                .padding(.horizontal, ToolbarMetrics.chipHorizontalPadding)
                .padding(.vertical, ToolbarMetrics.chipVerticalPadding)
                .background(
                    theme.info.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: ToolbarMetrics.chipCornerRadius, style: .continuous)
                )
                .help(helpText(for: currentStat))
            }
        }
        .onAppear(perform: reloadStat)
        .onChange(of: chatService.revision) { _, _ in
            reloadStat()
        }
        .onChange(of: chatService.selectedConversationID) { _, _ in
            reloadStat()
        }
    }

    private func reloadStat() {
        let conversationID = chatService.selectedConversationID
        guard let providerID = chatService.providerID(for: conversationID),
              let modelName = chatService.modelName(for: conversationID) else {
            currentStat = nil
            return
        }

        let messages = chatService.conversations.flatMap { chatService.messages(for: $0.id) }
        let snapshot = ModelSelectorStatsService.buildSnapshot(
            messages: messages,
            providers: chatService.providerInfos
        )
        currentStat = snapshot.detailedStats["\(providerID)|\(modelName)"]
    }

    private func helpText(for stat: ModelPerformanceStats) -> String {
        String(
            format: LumiPluginLocalization.string("Average TPS: %@ (%lld samples)", bundle: .module),
            ModelSelectorFormatService.tps(stat.avgTPS),
            stat.sampleCount
        )
    }
}
