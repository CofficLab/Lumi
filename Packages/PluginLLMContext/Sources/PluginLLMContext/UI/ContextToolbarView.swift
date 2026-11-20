import LumiUI
import ProviderConversation
import ProviderLLMContext
import ProviderLLMManager
import ProviderMessage
import SwiftUI

/// ChatToolbar 上的统一上下文按钮：窗口大小、用量、压缩记录。
@MainActor
struct ContextToolbarView: View {
    @LumiTheme private var theme

    let state: ContextToolbarState

    @State private var data: ContextToolbarData
    @State private var isPopoverPresented = false
    @State private var refreshRevision = 0
    @State private var observerHandle: (any ContextToolbarState.ObserverHandle)?

    init(provider: LLMContextProvider, messages: any MessageManaging, state: ContextToolbarState) {
        self.state = state
        _data = State(initialValue: ContextToolbarData(provider: provider, messages: messages))
    }

    private var displayedWindowSize: Int? {
        guard let usage = data.usage else { return nil }
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
            ContextPopover(
                usage: data.usage,
                history: data.history,
                events: data.events,
                auxiliaryEntries: data.auxiliaryEntries
            )
            .task {
                // 打开弹窗时补拉仅弹窗展示的数据（#1257）。
                await data.refreshPopoverOnly(for: data.selectedConversationID)
            }
        }
        .task(id: "\(data.selectedConversationID?.uuidString ?? "nil")-\(refreshRevision)") {
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            await data.refresh(isPopoverPresented: isPopoverPresented, for: data.selectedConversationID)
        }
        .onAppear {
            guard observerHandle == nil else { return }
            data.setSelectedConversationID(state.selectedConversationID)
            observerHandle = state.addObserver { event in
                switch event {
                case let .selectedConversationChanged(id):
                    data.setSelectedConversationID(id)
                    isPopoverPresented = false
                case let .messagesChanged(conversationID):
                    guard conversationID == data.selectedConversationID else { return }
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
                if let used = data.usage?.estimatedInputTokens, used > 0 {
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

            if !data.events.isEmpty {
                Image(systemName: "circle.fill")
                    .font(.system(size: 3))
                    .foregroundStyle(theme.warning)
                    .padding(.leading, 1)
                Text("\(data.events.count)")
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
        if !data.events.isEmpty { return theme.warning }
        return colorForUsage
    }

    private var colorForUsage: Color {
        guard let used = data.usage?.estimatedInputTokens,
              let limit = data.usage?.inputTokenLimit else {
            return theme.textSecondary
        }
        switch Self.usageSeverity(used: used, limit: limit) {
        case 2: return .red
        case 1: return theme.warning
        default: return theme.textSecondary
        }
    }

    /// 用量严重程度档位（0 正常 / 1 警告 / 2 危险）。
    ///
    /// 与弹窗的 `ContextUsageRing` 同口径：分母用输入预算（扣除输出预留、
    /// 工具 schema 与安全边际），而不是完整窗口大小。同一个快照在工具栏与
    /// 弹窗里必须显示同一档严重程度，否则工具栏会低估逼近发送预算的程度（#610）。
    nonisolated static func usageSeverity(used: Int, limit: Int) -> Int {
        guard used > 0, limit > 0 else { return 0 }
        let ratio = Double(used) / Double(limit)
        if ratio >= 0.9 { return 2 }
        if ratio >= 0.75 { return 1 }
        return 0
    }

    private var contextTooltip: String {
        guard let usage = data.usage else {
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
        let suffix = data.usage?.usesFallbackWindow == true ? "*" : ""
        return size.formattedContextSize + suffix
    }

}
