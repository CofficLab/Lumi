import Foundation
import MagicKit

/// 将 `AgentVM` 装配到各 Coordinator 的闭包集中于此，避免 `AgentVM.swift` 过长。
@MainActor
enum AgentVMCoordinatorBindings {
    static func makeMessageSendCoordinator(
        agent: AgentVM,
        messageSenderViewModel: MessageSenderVM,
        runtimeStore: ConversationRuntimeStore
    ) -> MessageSendCoordinator {
        MessageSendCoordinator(
            messageSenderViewModel: messageSenderViewModel,
            runtimeStore: runtimeStore,
            services: messageSendMiddlewareServices(agent: agent),
            onProcessingStarted: { [weak agent] conversationId in
                guard let agent else { return }
                if agent.ConversationVM.selectedConversationId == conversationId {
                    agent.processingStateViewModel.beginSending()
                }
            },
            onProcessingFinished: { [weak agent] conversationId in
                guard let agent else { return }
                if agent.ConversationVM.selectedConversationId == conversationId {
                    agent.processingStateViewModel.finish()
                }
            },
            sendMessageToAgent: { [weak agent] message, conversationId in
                guard let agent else { return }
                await agent.sendMessageToAgent(message: message, conversationId: conversationId)
            }
        )
    }

    static func makeConversationTurnCoordinator(
        agent: AgentVM,
        conversationTurnViewModel: ConversationTurnVM,
        runtimeStore: ConversationRuntimeStore,
        maxThinkingTextLength: Int,
        immediateStreamFlushChars: Int,
        immediateThinkingFlushChars: Int,
        captureThinkingContent: Bool,
        onFallbackEvent: @escaping (ConversationTurnEvent) async -> Void
    ) -> ConversationTurnCoordinator {
        ConversationTurnCoordinator(
            conversationTurnViewModel: conversationTurnViewModel,
            runtimeStore: runtimeStore,
            env: .init(
                selectedConversationId: { [weak agent] in agent?.ConversationVM.selectedConversationId },
                maxThinkingTextLength: maxThinkingTextLength,
                immediateStreamFlushChars: immediateStreamFlushChars,
                immediateThinkingFlushChars: immediateThinkingFlushChars,
                captureThinkingContent: captureThinkingContent
            ),
            messages: .init(
                messages: { [weak agent] in agent?.messages ?? [] },
                appendMessage: { [weak agent] m in agent?.appendMessage(m) },
                updateMessage: { [weak agent] m, idx in agent?.updateMessage(m, at: idx) },
                saveMessage: { [weak agent] m, cid in
                    guard let agent else { return }
                    await agent.saveMessage(m, conversationId: cid)
                },
                flushPendingStreamText: { [weak agent] cid, force in
                    agent?.flushPendingStreamTextIfNeeded(for: cid, force: force)
                },
                flushPendingThinkingText: { [weak agent] cid, force in
                    agent?.flushPendingThinkingTextIfNeeded(for: cid, force: force)
                },
                updateRuntimeState: { [weak agent] cid in
                    agent?.updateRuntimeState(for: cid)
                }
            ),
            ui: conversationTurnUIActions(agent: agent, runtimeStore: runtimeStore),
            onFallbackEvent: onFallbackEvent
        )
    }

    private static func messageSendMiddlewareServices(agent: AgentVM) -> MessageSendMiddlewareServices {
        MessageSendMiddlewareServices(
            getConversationTitle: { [weak agent] conversationId in
                agent?.chatHistoryService.fetchConversation(id: conversationId)?.title
            },
            getCurrentConfig: { [weak agent] in
                agent?.getCurrentConfig() ?? .default
            },
            generateConversationTitle: { [weak agent] content, config in
                guard let agent else { return String(content.prefix(20)) }
                return await agent.chatHistoryService.generateConversationTitle(from: content, config: config)
            },
            updateConversationTitleIfUnchanged: { [weak agent] conversationId, expectedTitle, newTitle in
                await MainActor.run {
                    guard let agent,
                          let conversation = agent.chatHistoryService.fetchConversation(id: conversationId),
                          conversation.title == expectedTitle else {
                        return false
                    }
                    agent.chatHistoryService.updateConversationTitle(conversation, newTitle: newTitle)
                    return true
                }
            },
            isProjectSelected: { [weak agent] in
                agent?.ProjectVM.isProjectSelected ?? false
            },
            getProjectInfo: { [weak agent] in
                (agent?.ProjectVM.currentProjectName ?? "", agent?.ProjectVM.currentProjectPath ?? "")
            },
            isFileSelected: { [weak agent] in
                agent?.ProjectVM.isFileSelected ?? false
            },
            getSelectedFileInfo: { [weak agent] in
                (agent?.ProjectVM.selectedFilePath ?? "", agent?.ProjectVM.selectedFileContent ?? "")
            },
            getSelectedText: {
                TextSelectionManager.shared.selectedText
            },
            getMessageCount: { [weak agent] conversationId in
                agent?.messageViewModel.messages.count ?? 0
            }
        )
    }

    private static func conversationTurnUIActions(
        agent: AgentVM,
        runtimeStore: ConversationRuntimeStore
    ) -> ConversationTurnCoordinator.UIActions {
        .init(
            setPendingPermissionRequest: { [weak agent] request, _ in
                agent?.setPendingPermissionRequest(request)
            },
            setDepthWarning: { [weak agent] warning, _ in
                agent?.setDepthWarning(warning)
            },
            onTurnFinishedUI: { [weak agent] _ in
                guard let agent else { return }
                agent.processingStateViewModel.finish()
            },
            onTurnFailedUI: { [weak agent] _, _ in
                guard let agent else { return }
                agent.processingStateViewModel.finish()
            },
            onStreamStartedUI: { [weak agent] _, conversationId in
                guard let agent else { return }
                agent.processingStateViewModel.markStreamStarted()
                if agent.ConversationVM.selectedConversationId == conversationId {
                    agent.bumpStreamingRenderVersion()
                }
            },
            onStreamFirstTokenUI: { [weak agent] _, ttftMs in
                guard let agent else { return }
                if let ttftMs {
                    agent.processingStateViewModel.markFirstToken(ttftMs: ttftMs)
                } else {
                    agent.processingStateViewModel.markGenerating()
                }
            },
            onStreamFinishedUI: { [weak agent] conversationId in
                guard let agent else { return }
                agent.setThinkingText(runtimeStore.thinkingTextByConversation[conversationId] ?? "", for: conversationId)
                agent.setIsThinking(false, for: conversationId)
                agent.processingStateViewModel.finish()
                runtimeStore.streamingTextByConversation[conversationId] = nil
                if agent.ConversationVM.selectedConversationId == conversationId {
                    agent.bumpStreamingRenderVersion()
                }
            },
            onThinkingStartedUI: { [weak agent] conversationId in
                guard let agent else { return }
                agent.setIsThinking(true, for: conversationId)
            },
            setLastHeartbeatTime: { [weak agent] date in
                agent?.setLastHeartbeatTime(date)
            },
            setIsThinking: { [weak agent] isThinking, cid in
                agent?.setIsThinking(isThinking, for: cid)
            },
            setThinkingText: { [weak agent] text, cid in
                agent?.setThinkingText(text, for: cid)
            }
        )
    }
}
