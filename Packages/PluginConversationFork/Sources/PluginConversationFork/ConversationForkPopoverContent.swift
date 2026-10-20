import LumiUI
import SwiftUI

/// 「续接到新对话」的引导弹窗。
///
/// 工具栏上的分叉按钮不再「点了就跑」：点击只打开本弹窗，把**将被带走的上下文**
/// （对话标题、消息条数、提问轮数、模型、最后一条提问）摊开给用户看，
/// 用户确认后才真正执行分叉。误触不再会凭空多出一个对话。
///
/// 视觉沿用 `PluginGoalTask` 里 Goal 分叉弹窗的语言（同一套 header + 分隔线 +
/// 滚动正文 + 底部确认按钮），因此两个分叉入口在应用里的观感一致。
struct ConversationForkPopoverContent: View {
    @LumiTheme private var theme

    /// 打开弹窗时锁定的源对话 ID。
    ///
    /// 刻意**不**跟随 `selectedConversationID` 实时变化：用户确认时看到的
    /// 必须是实际被分叉的那份上下文，否则预览与行为会错位。
    let conversationID: UUID?
    /// 预览数据，由工具栏按钮在弹窗弹出期间并行拉取。
    let preview: ConversationForkPreview?
    /// 预览是否仍在加载。
    let isPreviewLoading: Bool
    let coordinator: ConversationForkCoordinator
    @Binding var isPresented: Bool

    @State private var isForking = false
    @State private var errorMessage: String?
    @State private var phase: Phase = .idle

    /// 弹窗的阶段状态。
    private enum Phase {
        /// 待用户确认（分叉进行中由 `isForking` 单独表示）。
        case idle
        /// 分叉成功，但摘要走了本地回退，需要告知用户。
        case fallbackNotice
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider()
                .opacity(0.7)

            content

            Divider()
                .opacity(0.7)

            footer
        }
        .frame(width: 340, height: 380)
        .background(theme.background)
        .appThemedAppearance()
        .background {
            ThemeWindowAppearanceBridge()
        }
        .onAppear {
            // 弹窗可能被复用：每次呈现都重置上一次分叉残留的结果状态。
            phase = .idle
            errorMessage = nil
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.uturn.forward.circle")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(theme.primary)
                .frame(width: 28, height: 28)
                .background(
                    theme.primary.opacity(0.12),
                    in: Circle()
                )

            Text(pluginLocalization.string("Continue in a new conversation"))
                .font(.appCaptionEmphasized)
                .foregroundColor(theme.textPrimary)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if isPreviewLoading {
            VStack {
                Spacer()
                ProgressView()
                    .controlSize(.small)
                Spacer()
            }
        } else if conversationID == nil {
            emptyState(
                icon: "bubble.left.and.bubble.right",
                title: pluginLocalization.string("No conversation selected"),
                hint: pluginLocalization.string("Select a conversation first, then continue it in a new chat.")
            )
        } else if let preview, preview.hasContent {
            previewContent(preview)
        } else {
            emptyState(
                icon: "text.bubble",
                title: pluginLocalization.string("This conversation is empty"),
                hint: pluginLocalization.string("Send a message first, then continue it in a new chat.")
            )
        }
    }

    /// 预览正文：把将被带走的上下文摊开。
    private func previewContent(_ preview: ConversationForkPreview) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(preview.displayTitle)
                    .font(.headline)
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 6) {
                    metaChip(
                        icon: "text.bubble",
                        text: String(format: pluginLocalization.string("%lld messages"), preview.messageCount)
                    )
                    if preview.requestCount > 0 {
                        metaChip(
                            icon: "hand.raised",
                            text: String(format: pluginLocalization.string("%lld requests"), preview.requestCount)
                        )
                    }
                    Spacer(minLength: 0)
                }

                if let modelName = preview.modelName, !modelName.isEmpty {
                    metaRow(icon: "cpu", text: modelName)
                }

                if let projectPath = preview.projectPath, !projectPath.isEmpty {
                    metaRow(icon: "folder", text: projectPath)
                }

                if let lastRequest = preview.lastRequest, !lastRequest.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(pluginLocalization.string("Last request"))
                            .font(.caption2)
                            .foregroundColor(theme.textSecondary)

                        Text(lastRequest)
                            .font(.caption)
                            .foregroundColor(theme.textPrimary)
                            .lineLimit(3)
                            .truncationMode(.tail)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                Text(pluginLocalization.string("A summary of this conversation will be generated and sent as the first message in a new chat. The current conversation stays unchanged."))
                    .font(.caption)
                    .foregroundColor(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
        }
        .scrollIndicators(.automatic)
    }

    private func emptyState(icon: String, title: String, hint: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(theme.textTertiary)

            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(theme.textPrimary)

            Text(hint)
                .font(.caption)
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption2)
                    .foregroundStyle(theme.error)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if phase == .fallbackNotice {
                Text(pluginLocalization.string("Summary generation failed, used a compact fallback."))
                    .font(.caption2)
                    .foregroundStyle(theme.warning)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                Spacer(minLength: 0)

                if phase == .fallbackNotice {
                    Button(pluginLocalization.string("Done")) {
                        isPresented = false
                    }
                    .keyboardShortcut(.defaultAction)
                } else {
                    Button(pluginLocalization.string("Cancel")) {
                        isPresented = false
                    }
                    .keyboardShortcut(.cancelAction)

                    Button {
                        startFork()
                    } label: {
                        Group {
                            if isForking {
                                ProgressView()
                                    .controlSize(.mini)
                            } else {
                                Text(pluginLocalization.string("Continue in a new conversation"))
                            }
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(minWidth: 130)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isForking || !canFork)
                    .keyboardShortcut(.defaultAction)
                    .accessibilityLabel(
                        isForking
                            ? pluginLocalization.string("Summarizing conversation…")
                            : pluginLocalization.string("Continue in a new conversation")
                    )
                }

                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Pieces

    /// 统计胶囊（消息条数 / 提问轮数）。
    private func metaChip(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
            Text(text)
                .font(.caption2)
        }
        .foregroundColor(theme.textSecondary)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(theme.elevatedSurface, in: Capsule())
    }

    /// 单行元信息（模型 / 项目路径）。
    private func metaRow(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(theme.textSecondary)
                .frame(width: 14)

            Text(text)
                .font(.caption)
                .foregroundColor(theme.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 0)
        }
    }

    // MARK: - Actions

    /// 当前是否可以确认分叉：有源对话，且其中有可摘要的内容。
    private var canFork: Bool {
        conversationID != nil && preview?.hasContent == true
    }

    private func startFork() {
        guard !isForking, let conversationID else { return }
        isForking = true
        errorMessage = nil

        Task { @MainActor in
            defer { isForking = false }
            do {
                let outcome = try await coordinator.fork(conversationID: conversationID)
                if outcome.usedFallback {
                    // 摘要走了本地回退：结果依然可用，但需要如实告知用户。
                    phase = .fallbackNotice
                } else {
                    isPresented = false
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
