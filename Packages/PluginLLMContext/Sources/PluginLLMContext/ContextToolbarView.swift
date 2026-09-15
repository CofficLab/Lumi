import LumiUI
import ProviderConversation
import ProviderLLMManager
import ProviderMessage
import SwiftUI

/// ChatToolbar 上的统一上下文按钮：窗口大小、用量、压缩记录。
@MainActor
struct ContextToolbarView: View {
    @LumiTheme private var theme

    let provider: LLMContextProvider
    let messages: any MessageManaging
    let state: ContextToolbarState

    @State private var usage: ContextWindowUsageSnapshot?
    @State private var history: ContextUsageHistory = .empty
    @State private var events: [Message] = []
    @State private var isPopoverPresented = false
    @State private var selectedConversationID: UUID?
    @State private var refreshRevision = 0
    @State private var observerHandle: (any ContextToolbarState.ObserverHandle)?

    private var displayedWindowSize: Int? {
        guard let usage else { return nil }
        return usage.contextWindowTokens
            ?? (usage.usesFallbackWindow ? usage.effectiveContextWindowTokens : nil)
    }

    var body: some View {
        Button {
            isPopoverPresented.toggle()
        } label: {
            buttonLabel
        }
        .buttonStyle(.plain)
        .help(contextTooltip)
        .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
            ContextPopover(usage: usage, history: history, events: events)
        }
        .task(id: "\(selectedConversationID?.uuidString ?? "nil")-\(refreshRevision)") {
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            await refreshUsage(for: selectedConversationID)
            await refreshHistory(for: selectedConversationID)
            await refreshEvents(for: selectedConversationID)
        }
        .onAppear {
            guard observerHandle == nil else { return }
            selectedConversationID = state.selectedConversationID
            observerHandle = state.addObserver { event in
                switch event {
                case let .selectedConversationChanged(id):
                    selectedConversationID = id
                    isPopoverPresented = false
                case let .messagesChanged(conversationID):
                    guard conversationID == selectedConversationID else { return }
                    refreshRevision &+= 1
                case .llmChanged:
                    refreshRevision &+= 1
                }
            }
        }
        .onDisappear {
            observerHandle?.cancel()
            observerHandle = nil
        }
    }

    // MARK: - Button

    private var buttonLabel: some View {
        HStack(spacing: 4) {
            Image(systemName: "text.viewfinder")
                .font(.system(size: 10))
            if let displayedWindowSize, displayedWindowSize > 0 {
                if let used = usage?.estimatedInputTokens, used > 0 {
                    Text("\(used.formattedTokensShort)/\(formattedWindowSize(displayedWindowSize))")
                        .font(.system(size: 10, weight: .medium))
                        .monospacedDigit()
                } else {
                    Text(formattedWindowSize(displayedWindowSize))
                        .font(.system(size: 10, weight: .medium))
                        .monospacedDigit()
                }
            } else {
                Text(String(localized: "Context: Unknown", defaultValue: "上下文：未知", bundle: .module))
                    .font(.system(size: 10, weight: .medium))
            }

            if !events.isEmpty {
                Image(systemName: "circle.fill")
                    .font(.system(size: 3))
                    .foregroundStyle(theme.warning)
                    .padding(.leading, 1)
                Text("\(events.count)")
                    .font(.system(size: 10, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(theme.warning)
            }
        }
        .foregroundStyle(labelColor)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            theme.appStatusMutedFill,
            in: RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous)
        )
        .contentShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous))
    }

    private var labelColor: Color {
        if !events.isEmpty { return theme.warning }
        return colorForUsage
    }

    private var colorForUsage: Color {
        guard let used = usage?.estimatedInputTokens,
              let displayedWindowSize,
              displayedWindowSize > 0 else {
            return theme.textSecondary
        }
        let ratio = Double(used) / Double(displayedWindowSize)
        if ratio >= 0.9 { return .red }
        if ratio >= 0.75 { return theme.warning }
        return theme.textSecondary
    }

    private var contextTooltip: String {
        guard let usage else {
            return String(localized: "Context window size is unknown", defaultValue: "上下文窗口大小未知", bundle: .module)
        }
        if let used = usage.estimatedInputTokens,
           let displayedWindowSize {
            let template = String(
                localized: "Estimated input: %@ / %@ context window",
                defaultValue: "估算输入：%@ / %@ 上下文窗口",
                bundle: .module
            )
            return String(format: template, used.formattedTokensShort, formattedWindowSize(displayedWindowSize))
        }
        if let displayedWindowSize {
            return String(
                format: String(
                    localized: "Context window: %@ tokens",
                    defaultValue: "上下文窗口：%@ tokens",
                    bundle: .module
                ),
                formattedWindowSize(displayedWindowSize)
            )
        }
        return String(localized: "Context window size is unknown", defaultValue: "上下文窗口大小未知", bundle: .module)
    }

    private func formattedWindowSize(_ size: Int) -> String {
        let suffix = usage?.usesFallbackWindow == true ? "*" : ""
        return size.formattedContextSize + suffix
    }

    // MARK: - Data

    private func refreshUsage(for conversationID: UUID?) async {
        let snapshot = await provider.contextWindowUsage(for: conversationID)
        guard !Task.isCancelled, selectedConversationID == conversationID else { return }
        usage = snapshot
    }

    private func refreshHistory(for conversationID: UUID?) async {
        guard let conversationID else {
            history = .empty
            return
        }
        let snapshot = await messages.messagesSnapshot(in: conversationID)
        guard !Task.isCancelled, selectedConversationID == conversationID else { return }
        history = ContextUsageHistory.build(from: snapshot)
    }

    private func refreshEvents(for conversationID: UUID?) async {
        guard let conversationID else {
            events = []
            return
        }
        let snapshot = await messages.messagesSnapshot(in: conversationID)
        guard !Task.isCancelled, selectedConversationID == conversationID else { return }
        events = snapshot
            .filter(MessageTimelineEvent.isActualContextCompaction)
            .sorted { lhs, rhs in
                if lhs.createdAt == rhs.createdAt { return lhs.id > rhs.id }
                return lhs.createdAt > rhs.createdAt
            }
    }
}
