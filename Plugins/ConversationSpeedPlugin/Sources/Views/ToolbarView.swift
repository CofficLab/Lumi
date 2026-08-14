import SwiftUI
import KernelLumi

/// 会话流式速度工具条按钮（chip 样式），点击弹出速度详情。
struct ToolbarView: View {
    // selectedConversationID 由 .onLumiSelectedConversationDidChange 事件更新；
    // 消息变更由 .onLumiMessagesDidChange 精确覆盖。
    // 不挂 kernel 全局总线，project/settings 等无关服务变更不会触发这里刷新。
    let kernel: KernelLumi
    @State private var selectedConversationID: UUID?

    @State private var cachedTPS: Double?
    @State private var unavailabilityReason: ConversationSpeedUnavailability = .waitingForResponse
    @State private var popoverShown = false
    @State private var speedHistory: [SpeedSample] = []

    // Detail data shown inside the popover.
    @State private var modelName: String?
    @State private var outputTokens: Int?
    @State private var streamingDurationMs: Double?
    @State private var timeToFirstTokenMs: Double?
    @State private var providerID: String?

    var body: some View {
        Group {
            if selectedConversationID != nil {
                Button {
                    popoverShown.toggle()
                } label: {
                    HStack(spacing: ToolbarMetrics.chipSpacing) {
                        Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                            .font(.system(size: ToolbarMetrics.chipIconSize, weight: .medium))
                        Text(speedLabel)
                            .font(.system(size: ToolbarMetrics.chipTextSize, weight: ToolbarMetrics.chipTextWeight))
                            .contentTransition(.numericText())
                    }
                    .foregroundColor(cachedTPS == nil ? .secondary : .orange)
                    .padding(.horizontal, ToolbarMetrics.chipHorizontalPadding)
                    .padding(.vertical, ToolbarMetrics.chipVerticalPadding)
                    .background(
                        cachedTPS == nil ? Color.secondary.opacity(0.12) : Color.orange.opacity(0.22),
                        in: RoundedRectangle(cornerRadius: ToolbarMetrics.chipCornerRadius, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
                .help(LumiPluginLocalization.string("Streaming speed help", bundle: .module))
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
            } else {
                EmptyView()
            }
        }
        .onLumiMessagesDidChange { eventConversationID in
            guard eventConversationID == nil
                || eventConversationID == selectedConversationID else { return }
            self.updateTPS()
        }
        .onAppear {
            self.updateTPS()
        }
        .onChange(of: selectedConversationID) { oldValue, newValue in
            // 切换会话时重算速度（消息变更由 onLumiMessagesDidChange 覆盖）。
            if oldValue != newValue {
                resetDisplayState()
            }
            if newValue == nil {
                popoverShown = false
            }
            self.updateTPS()
        }
        .task {
            selectedConversationID = kernel.conversations?.selectedConversationID
        }
        .onLumiSelectedConversationDidChange { newID in
            selectedConversationID = newID
        }
    }

    private var speedLabel: String {
        guard let cachedTPS else {
            return LumiPluginLocalization.string("Speed unavailable", bundle: .module)
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
            if ConversationSpeedPlugin.verbose {
                ConversationSpeedPlugin.logger.info("\(ConversationSpeedPlugin.t)No selected conversation ID")
            }
            return
        }

        guard let messageManager = kernel.messageManager else {
            return
        }

        let messages = messageManager.messages(for: conversationID)
        let history = SpeedSample.samples(from: messages)
        speedHistory = history

        guard let lastMessage = messages.last ?? messageManager.lastMessage(in: conversationID) else {
            cachedTPS = nil
            unavailabilityReason = .waitingForResponse
            if ConversationSpeedPlugin.verbose {
                ConversationSpeedPlugin.logger.info("\(ConversationSpeedPlugin.t)No last message for conversation \(conversationID.uuidString.prefix(8))")
            }
            return
        }
        let latestAssistantMessage = messages.last(where: { $0.role == .assistant })
        let latestSpeedMessage = history.last?.message ?? latestAssistantMessage ?? lastMessage

        // Capture detail data for the popover.
        modelName = latestSpeedMessage.modelName
        outputTokens = latestSpeedMessage.outputTokenCount ?? Int(latestSpeedMessage.metadata["outputTokens"] ?? "")
        streamingDurationMs = latestSpeedMessage.conversationSpeedDurationMs
        timeToFirstTokenMs = latestSpeedMessage.timeToFirstTokenMs ?? Double(latestSpeedMessage.metadata["timeToFirstTokenMs"] ?? "")
        providerID = latestSpeedMessage.providerID

        // Prefer the effective duration-based value. A provider may deliver the
        // whole response in one chunk, making the post-first-token duration only
        // a few milliseconds even though the user waited several seconds.
        if let tps = history.last?.tokensPerSecond ?? lastMessage.conversationSpeedTokensPerSecond {
            if ConversationSpeedPlugin.verbose {
                ConversationSpeedPlugin.logger.info("\(ConversationSpeedPlugin.t)tokensPerSecond from property: \(tps)")
            }
            cachedTPS = tps
            return
        }

        cachedTPS = nil
        unavailabilityReason = ConversationSpeedUnavailability.reason(for: latestAssistantMessage)
        if ConversationSpeedPlugin.verbose {
            ConversationSpeedPlugin.logger.info("\(ConversationSpeedPlugin.t)Cannot calculate TPS: \(self.unavailabilityReason.rawValue)")
        }
    }
}

/// 工具条 chip 布局度量。
enum ToolbarMetrics {
    static let chipIconSize: CGFloat = 10
    static let chipTextSize: CGFloat = 10
    static let chipTextWeight: Font.Weight = .medium
    static let chipSpacing: CGFloat = 3
    static let chipHorizontalPadding: CGFloat = 6
    static let chipVerticalPadding: CGFloat = 3
    static let chipCornerRadius: CGFloat = 5
}
