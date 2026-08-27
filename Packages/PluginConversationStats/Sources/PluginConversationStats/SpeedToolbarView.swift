import ProviderConversation
import ProviderMessage
import SwiftUI

/// 流式速度工具栏视图
struct SpeedToolbarView: View {
    let conversations: any ConversationManaging
    let messages: any MessageManaging

    @State private var selectedConversationID: UUID?
    @State private var cachedTPS: Double?
    @State private var unavailabilityReason: SpeedUnavailability = .waitingForResponse
    @State private var popoverShown = false
    @State private var speedHistory: [SpeedSample] = []

    // Popover detail data
    @State private var modelName: String?
    @State private var outputTokens: Int?
    @State private var streamingDurationMs: Double?
    @State private var timeToFirstTokenMs: Double?
    @State private var providerID: String?

    // Observer tokens
    @State private var conversationObserver: (any SelectedConversationObserverHandle)?
    @State private var messageObserver: (any MessageInsertedObserverHandle)?

    var body: some View {
        Button {
            popoverShown.toggle()
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                    .font(.system(size: 10, weight: .medium))
                Text(speedLabel)
                    .font(.system(size: 10, weight: .medium))
                    .contentTransition(.numericText())
            }
            .foregroundColor(cachedTPS == nil ? .secondary : .orange)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                cachedTPS == nil ? Color.secondary.opacity(0.12) : Color.orange.opacity(0.22),
                in: RoundedRectangle(cornerRadius: 5, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .help(LumiPluginLocalization.string("Streaming output speed", bundle: .module))
        .popover(isPresented: $popoverShown, arrowEdge: .bottom) {
            SpeedPopover(
                tps: cachedTPS,
                unavailabilityReason: unavailabilityReason,
                modelName: modelName,
                outputTokens: outputTokens,
                streamingDurationMs: streamingDurationMs,
                timeToFirstTokenMs: timeToFirstTokenMs,
                providerID: providerID,
                speedHistory: speedHistory
            )
            .frame(width: 360)
        }
        .task {
            selectedConversationID = conversations.selectedConversationID
            updateTPS()
            conversationObserver = conversations.addSelectedConversationObserver { newID in
                selectedConversationID = newID
                if newID == nil { popoverShown = false }
                updateTPS()
            }
            messageObserver = messages.addMessageInsertedObserver { _, conversationID in
                if conversationID == selectedConversationID || conversationID == conversations.selectedConversationID {
                    updateTPS()
                }
            }
        }
        .onChange(of: selectedConversationID) { oldValue, newValue in
            if oldValue != newValue {
                resetDisplayState()
            }
            if newValue == nil {
                popoverShown = false
            }
            updateTPS()
        }
    }

    private var speedLabel: String {
        guard let cachedTPS else {
            return "—"
        }
        return String(format: "%.1f tok/s", cachedTPS)
    }

    private func resetDisplayState() {
        cachedTPS = nil
        unavailabilityReason = .waitingForResponse
        speedHistory = []
        modelName = nil
        outputTokens = nil
        streamingDurationMs = nil
        timeToFirstTokenMs = nil
        providerID = nil
    }

    private func updateTPS() {
        guard let conversationID = selectedConversationID else {
            cachedTPS = nil
            unavailabilityReason = .noConversationSelected
            speedHistory = []
            modelName = nil
            outputTokens = nil
            streamingDurationMs = nil
            timeToFirstTokenMs = nil
            providerID = nil
            return
        }

        let allMessages = messages.messages(for: conversationID)
        let history = SpeedSample.samples(from: allMessages)
        speedHistory = history

        guard let lastMessage = allMessages.last ?? messages.lastMessage(in: conversationID) else {
            cachedTPS = nil
            unavailabilityReason = .waitingForResponse
            return
        }

        let latestAssistantMessage = allMessages.last(where: { $0.role == .assistant })
        let latestSpeedMessage = history.last?.message ?? latestAssistantMessage ?? lastMessage

        // Capture detail data for the popover
        modelName = latestSpeedMessage.modelName
        outputTokens = latestSpeedMessage.outputTokenCount
        streamingDurationMs = latestSpeedMessage.speedDurationMs
        timeToFirstTokenMs = latestSpeedMessage.timeToFirstTokenMs
        providerID = latestSpeedMessage.providerID

        // Prefer effective duration-based value
        if let tps = history.last?.tokensPerSecond ?? lastMessage.speedTokensPerSecond {
            cachedTPS = tps
            return
        }

        cachedTPS = nil
        unavailabilityReason = SpeedUnavailability.reason(for: latestAssistantMessage)
    }
}
