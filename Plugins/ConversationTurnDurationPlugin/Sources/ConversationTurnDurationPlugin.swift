import LumiChatKit
import LumiCoreKit
import LumiUI
import SwiftUI
import Combine

/// 对话轮次时长显示插件：在 Chat 工具栏显示当前轮次已持续的时间。
public enum ConversationTurnDurationPlugin: LumiPlugin {

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.conversation-turn-duration",
        displayName: LumiPluginLocalization.string("Turn Duration", bundle: .module),
        description: LumiPluginLocalization.string("Shows the duration of the current conversation turn", bundle: .module),
        order: 86,
        category: .agent,
        policy: .alwaysOn,
        stage: .beta,
        iconName: "clock",
    )

    @MainActor
    public static func chatSectionToolbarBarItems(context: LumiPluginContext) -> [LumiChatSectionToolbarBarItem] {
        guard context.showsChatSection,
              let chatService = context.resolve(LumiChatServicing.self)
        else {
            return []
        }

        return [
            LumiChatSectionToolbarBarItem(id: info.id, order: info.order) {
                TurnDurationToolbarView(chatService: chatService)
            }
        ]
    }
}

// MARK: - ViewModel

@MainActor
final class TurnDurationViewModel: ObservableObject {
    @Published private(set) var durationText: String = "--:--"
    @Published private(set) var isRunning: Bool = false
    
    // Exposed for testing
    var turnStartTime: Date?

    private let chatService: any LumiChatServicing
    private var concreteChatService: ChatService?
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var lastRevision: Int = 0

    init(chatService: any LumiChatServicing) {
        self.chatService = chatService
        self.concreteChatService = chatService as? ChatService
        self.lastRevision = chatService.revision

        // 监听 revision 变化来检测新轮次开始或结束
        if let concreteService = concreteChatService {
            concreteService.$revision
                .sink { [weak self] _ in
                    self?.checkAndUpdateTurn()
                }
                .store(in: &cancellables)
        }

        checkAndUpdateTurn()
    }

    deinit {
        Task { @MainActor [weak self] in
            self?.timer?.invalidate()
        }
    }

    private func checkAndUpdateTurn() {
        let conversationID = chatService.selectedConversationID
        let sending = chatService.isSending(for: conversationID)

        if sending && turnStartTime == nil {
            // 新轮次开始：找到最后一条用户消息的时间
            if let convID = conversationID {
                let messages = chatService.messages(for: convID)
                if let lastUserMessage = messages.last(where: { $0.role == .user }) {
                    turnStartTime = lastUserMessage.createdAt
                    startTimer()
                }
            }
        } else if !sending {
            // 轮次结束
            stopTimer()
            turnStartTime = nil
            durationText = "--:--"
        }

        isRunning = sending
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.internalUpdateDuration()
            }
        }
        internalUpdateDuration()
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    // Exposed for testing
    func updateDuration() {
        guard let startTime = turnStartTime else {
            durationText = "--:--"
            return
        }

        let elapsed = Date().timeIntervalSince(startTime)
        durationText = formatDuration(elapsed)
    }

    private func internalUpdateDuration() {
        updateDuration()
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60

        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return String(format: "%d:%02d:%02d", hours, remainingMinutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
}

// MARK: - View

private struct TurnDurationToolbarView: View {
    @StateObject private var viewModel: TurnDurationViewModel
    @LumiTheme private var theme

    init(chatService: any LumiChatServicing) {
        _viewModel = StateObject(wrappedValue: TurnDurationViewModel(chatService: chatService))
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "clock")
                .font(.caption)
                .foregroundColor(viewModel.isRunning ? theme.primary : theme.textSecondary)

            Text(viewModel.durationText)
                .font(.caption)
                .monospacedDigit()
                .foregroundColor(viewModel.isRunning ? theme.primary : theme.textSecondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(theme.background.opacity(0.5))
        .cornerRadius(6)
        .help(LumiPluginLocalization.string("Current turn duration", bundle: .module))
    }
}
