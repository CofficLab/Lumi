import LumiUI
import SwiftUI

/// ChatToolbar 上的模型上下文窗口和当前输入估算。
@MainActor
struct ContextWindowToolbarView: View {
    @LumiTheme private var theme

    let provider: LLMContextProvider
    let state: ContextCompactionToolbarState

    @State private var usage: ContextWindowUsageSnapshot?
    @State private var isPopoverPresented = false
    @State private var selectedConversationID: UUID?
    @State private var refreshRevision = 0
    @State private var observerHandle: (any ContextCompactionToolbarState.ObserverHandle)?

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
            ContextWindowPopover(usage: usage)
        }
        .task(id: "\(selectedConversationID?.uuidString ?? "nil")-\(refreshRevision)") {
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            await refreshUsage(for: selectedConversationID)
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

    private var buttonLabel: some View {
        HStack(spacing: 3) {
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
        }
        .foregroundStyle(colorForUsage)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            theme.appStatusMutedFill,
            in: RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous)
        )
        .contentShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous))
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

    private func refreshUsage(for conversationID: UUID?) async {
        let snapshot = await provider.contextWindowUsage(for: conversationID)
        guard !Task.isCancelled, selectedConversationID == conversationID else { return }
        usage = snapshot
    }
}

private struct ContextWindowPopover: View {
    @LumiTheme private var theme

    let usage: ContextWindowUsageSnapshot?

    private var contextWindowSize: Int? {
        guard let usage else { return nil }
        return usage.contextWindowTokens
            ?? (usage.usesFallbackWindow ? usage.effectiveContextWindowTokens : nil)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "text.viewfinder")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
                Text(String(localized: "Context Window", defaultValue: "上下文窗口", bundle: .module))
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            if let contextWindowSize {
                Text(contextWindowSize.formattedContextSize + (usage?.usesFallbackWindow == true ? "*" : ""))
                    .font(.system(size: 34, weight: .bold))
                    .monospacedDigit()
            } else {
                Text(String(localized: "Unknown", defaultValue: "未知", bundle: .module))
                    .font(.system(size: 28, weight: .bold))
            }

            if let usage, let estimated = usage.estimatedInputTokens, estimated > 0 {
                Text(String(
                    format: String(
                        localized: "Estimated input: %@ tokens",
                        defaultValue: "估算输入：%@ tokens",
                        bundle: .module
                    ),
                    estimated.formattedTokensShort
                ))
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)

                Text(String(
                    format: String(
                        localized: "LLMContext input budget: %@ tokens",
                        defaultValue: "LLMContext 输入预算：%@ tokens",
                        bundle: .module
                    ),
                    usage.inputTokenLimit.formattedTokensShort
                ))
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(theme.divider)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(colorForUsage(estimated: estimated, limit: usage.inputTokenLimit))
                            .frame(width: geo.size.width * min(
                                Double(estimated) / Double(max(usage.inputTokenLimit, 1)),
                                1.0
                            ))
                    }
                }
                .frame(height: 6)
            } else if usage?.estimatedInputTokens == 0 {
                Text(String(localized: "No token usage data yet", defaultValue: "暂无令牌使用数据", bundle: .module))
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
            } else {
                Text(String(localized: "No token usage data yet", defaultValue: "暂无令牌使用数据", bundle: .module))
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
            }

            if usage?.usesFallbackWindow == true, let usage {
                Text(String(
                    format: String(
                        localized: "Model window unknown; using a %@ fallback.",
                        defaultValue: "模型窗口未知，使用 %@ 作为估算值。",
                        bundle: .module
                    ),
                    usage.effectiveContextWindowTokens.formattedContextSize
                ))
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
            } else {
                Text(String(localized: "Input estimate and budget use the same LLMContext rules as compaction.", defaultValue: "输入估算和预算使用与 LLMContext 压缩相同的口径。", bundle: .module))
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
            }

            Divider()

            Text("上下文窗口是模型单次请求可处理的最大 token 数。输入估算使用 LLMContext 同一套规则；输入预算会为输出、工具 schema 和安全余量预留空间。")
                .font(.caption)
                .foregroundStyle(theme.textSecondary)
        }
        .padding(12)
        .frame(width: 280)
    }

    private func colorForUsage(estimated: Int, limit: Int) -> Color {
        guard limit > 0 else { return theme.textSecondary }
        let ratio = Double(estimated) / Double(limit)
        if ratio >= 0.9 { return .red }
        if ratio >= 0.75 { return theme.warning }
        return theme.textSecondary
    }
}
