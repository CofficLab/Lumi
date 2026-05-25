import LumiUI
import SwiftUI

struct ConversationHandoffSidebarSection: View {
    @EnvironmentObject private var chatHistoryVM: AppChatHistoryVM
    @EnvironmentObject private var conversationVM: WindowConversationVM
    @EnvironmentObject private var llmVM: AppLLMVM
    @EnvironmentObject private var projectVM: WindowProjectVM
    @EnvironmentObject private var themeVM: AppThemeVM

    @State private var isSummarizing = false
    @State private var statusText: String?
    @State private var errorText: String?
    @State private var currentContextTokens = 0
    @State private var refreshTask: Task<Void, Never>?

    private let service = ConversationHandoffSummaryService()
    private let timelineService = ConversationTimelineService()
    private let visibilityThreshold = 0.8

    var body: some View {
        Group {
            if shouldShowHandoff {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.appCaptionEmphasized)
                            .foregroundStyle(themeVM.activeChromeTheme.workspaceSecondaryTextColor())

                        Text("上下文交接")
                            .font(.appCaptionEmphasized)
                            .foregroundStyle(themeVM.activeChromeTheme.workspaceTextColor())

                        Spacer(minLength: 0)

                        if isSummarizing {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }

                    AppButton(
                        isSummarizing ? "正在总结..." : "总结并开启新对话",
                        systemImage: "sparkles",
                        style: .secondary,
                        size: .small,
                        fillsWidth: true
                    ) {
                        startHandoff()
                    }
                    .disabled(isSummarizing || conversationVM.selectedConversationId == nil)

                    if let statusText {
                        Text(statusText)
                            .font(.appCaption)
                            .foregroundStyle(themeVM.activeChromeTheme.workspaceSecondaryTextColor())
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let errorText {
                        Text(errorText)
                            .font(.appCaption)
                            .foregroundStyle(Color.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(themeVM.activeChromeTheme.workspaceBackgroundColor())
            }
        }
        .onAppear {
            refreshContextUsage()
        }
        .onDisappear {
            refreshTask?.cancel()
            refreshTask = nil
        }
        .onChange(of: conversationVM.selectedConversationId) { _, _ in
            refreshContextUsage()
        }
        .onMessageSaved { _, conversationId in
            guard conversationId == conversationVM.selectedConversationId else { return }
            scheduleContextUsageRefresh(for: conversationId)
        }
    }

    private var shouldShowHandoff: Bool {
        timelineService.contextUsageRatio(
            currentTokens: currentContextTokens,
            limit: currentModelContextLimit
        ) >= visibilityThreshold
    }

    private var currentModelContextLimit: Int {
        let preference = conversationVM.getModelPreference()
        return timelineService.contextLimit(
            providerId: preference?.providerId ?? llmVM.selectedProviderId,
            model: preference?.model ?? llmVM.currentModel,
            providers: llmVM.availableProviders
        )
    }

    private func startHandoff() {
        guard !isSummarizing else { return }
        isSummarizing = true
        statusText = nil
        errorText = nil

        Task {
            await summarizeAndCreateConversation()
        }
    }

    @MainActor
    private func summarizeAndCreateConversation() async {
        defer { isSummarizing = false }

        do {
            guard let sourceConversationId = conversationVM.selectedConversationId else {
                throw ConversationHandoffSummaryError.missingConversation
            }
            guard let messages = chatHistoryVM.loadMessagesAsync(forConversationId: sourceConversationId) else {
                throw ConversationHandoffSummaryError.missingConversation
            }

            let modelPreference = conversationVM.getModelPreference(for: sourceConversationId)
            let config = conversationVM.resolveModelConfig(
                for: sourceConversationId,
                fallbackConfigProvider: llmVM
            )

            statusText = "正在生成摘要..."
            let summary = try await service.summarize(
                messages: messages,
                config: config,
                llmService: llmVM.llmService
            )

            statusText = "正在创建新对话..."
            await conversationVM.createNewConversation(
                projectName: projectVM.isProjectSelected ? projectVM.currentProjectName : nil,
                projectPath: projectVM.isProjectSelected ? projectVM.currentProjectPath : nil,
                languagePreference: projectVM.languagePreference
            )

            guard let targetConversationId = conversationVM.selectedConversationId else {
                throw ConversationHandoffSummaryError.missingConversation
            }

            if let modelPreference {
                conversationVM.saveModelPreference(
                    for: targetConversationId,
                    providerId: modelPreference.providerId,
                    model: modelPreference.model
                )
            }

            let handoff = ChatMessage(
                role: .user,
                conversationId: targetConversationId,
                content: service.handoffMessage(from: summary)
            )
            conversationVM.saveMessage(handoff, to: targetConversationId)

            if let conversation = conversationVM.fetchConversation(id: targetConversationId) {
                conversationVM.updateConversationTitle(conversation, newTitle: "上下文交接")
            }

            statusText = "已创建带摘要的新对话"
        } catch {
            errorText = error.localizedDescription
            statusText = nil
        }
    }

    private func refreshContextUsage() {
        refreshTask?.cancel()
        refreshTask = nil

        guard let conversationId = conversationVM.selectedConversationId else {
            currentContextTokens = 0
            return
        }

        let summary = chatHistoryVM.getConversationTimelineSummary(forConversationId: conversationId)
        currentContextTokens = summary.currentContextTokens
    }

    private func scheduleContextUsageRefresh(for conversationId: UUID) {
        refreshTask?.cancel()
        refreshTask = Task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard conversationVM.selectedConversationId == conversationId else { return }
                refreshContextUsage()
            }
        }
    }
}
