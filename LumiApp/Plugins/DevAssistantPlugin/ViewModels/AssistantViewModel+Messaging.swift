import Foundation
import MagicKit
import OSLog

// MARK: - 消息发送与处理

extension AssistantViewModel {
    // MARK: - 消息发送

    func sendMessage() {
        guard !currentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !pendingAttachments.isEmpty else { return }

        if Self.verbose {
            os_log("\(self.t) 用户发送消息")
        }

        // 清除之前的深度警告
        depthWarning = nil

        // 检查是否已选择项目
        if !isProjectSelected {
            Task {
                let warningContent = await promptService.getProjectNotSelectedWarningMessage()
                let warningMsg = ChatMessage(
                    role: .assistant,
                    content: warningContent,
                    isError: true
                )
                messages.append(warningMsg)
            }
            return
        }

        let input = currentInput
        currentInput = ""
        isProcessing = true
        errorMessage = nil

        // 检查是否为斜杠命令
        if input.hasPrefix("/") {
            Task {
                let result = await SlashCommandService.shared.handle(input: input, viewModel: self)
                switch result {
                case .handled:
                    isProcessing = false
                    self.pendingAttachments.removeAll()
                case let .error(msg):
                    messages.append(ChatMessage(role: .assistant, content: "Command Error: \(msg)", isError: true))
                    isProcessing = false
                    self.pendingAttachments.removeAll()
                case .notHandled:
                    await processUserMessage(input: input)
                }
            }
            return
        }

        currentTask = Task {
            await processUserMessage(input: input)
        }
    }

    func processUserMessage(input: String) async {
        var finalContent = input

        // 处理附件 - 转换为结构化图片数据
        var images: [ImageAttachment] = []
        if !pendingAttachments.isEmpty {
            if Self.verbose {
                os_log("\(self.t)📎 处理 \(self.pendingAttachments.count) 个附件")
            }
            for attachment in pendingAttachments {
                if case .image(_, let data, let mimeType, _) = attachment {
                    images.append(ImageAttachment(data: data, mimeType: mimeType))
                    if Self.verbose {
                        os_log("\(self.t) - 图片：\(mimeType), 大小：\(data.count) bytes")
                    }
                }
            }
            pendingAttachments.removeAll()
        } else if Self.verbose {
            os_log("\(self.t)📎 无附件")
        }

        let userMsg = ChatMessage(role: .user, content: finalContent, images: images)

        if Self.verbose && !images.isEmpty {
            os_log("\(self.t)✅ 用户消息包含 \(images.count) 张图片")
        }

        messages.append(userMsg)
        
        // 立即保存用户消息
        saveMessage(userMsg)
        
        // 生成会话标题（如果是第一条用户消息）
        await generateTitleIfNeeded(userMessage: finalContent)

        await processTurn()
    }

    // MARK: - 对话轮次处理

    func processTurn(depth: Int = 0) async {
        let maxDepth = 100

        guard depth < maxDepth else {
            errorMessage = "Max recursion depth reached."
            isProcessing = false
            depthWarning = DepthWarning(currentDepth: depth, maxDepth: maxDepth, warningType: .reached)
            os_log(.error, "\(self.t) 达到最大递归深度 (\(maxDepth))，对话终止")
            return
        }

        currentDepth = depth
        if Self.verbose {
            os_log("\(self.t) 开始处理对话轮次 (深度：\(depth), 模式：\(self.chatMode.displayName))")
        }

        // 更新深度警告状态
        updateDepthWarning(currentDepth: depth, maxDepth: maxDepth)

        // 根据聊天模式决定是否传递工具
        let availableTools: [AgentTool] = (chatMode == .build) ? tools : []

        if Self.verbose && chatMode == .chat {
            os_log("\(self.t) 当前为对话模式，不传递工具")
        }

        do {
            let config = getCurrentConfig()

            if Self.verbose {
                os_log("\(self.t) 调用 LLM (供应商：\(config.providerId), 模型：\(config.model))")
            }

            // 1. 获取 LLM 响应
            var responseMsg = try await llmService.sendMessage(messages: messages, config: config, tools: availableTools)
            
            // 检查内容是否为空（只有空白字符）
            let hasContent = !responseMsg.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let hasToolCalls = responseMsg.toolCalls != nil && !responseMsg.toolCalls!.isEmpty
            
            // 当无内容但有工具调用时，生成一个友好的提示消息
            if !hasContent && hasToolCalls {
                // 生成工具调用摘要
                let toolSummary = responseMsg.toolCalls!.enumerated().map { index, tc in
                    let emoji = toolEmoji(for: tc.name)
                    return "\(emoji) \(tc.name)"
                }.joined(separator: "\n")
                
                let prefix = languagePreference == .chinese 
                    ? "🔧 正在执行 \(responseMsg.toolCalls!.count) 个工具："
                    : "🔧 Executing \(responseMsg.toolCalls!.count) tools:"
                
                let enhancedContent = prefix + "\n" + toolSummary
                responseMsg = ChatMessage(
                    role: responseMsg.role,
                    content: enhancedContent,
                    isError: responseMsg.isError,
                    toolCalls: responseMsg.toolCalls,
                    toolCallID: responseMsg.toolCallID
                )
                
                if Self.verbose {
                    os_log("%{public}@📝 为空内容消息生成工具摘要", self.t)
                }
            }
            
            messages.append(responseMsg)
            
            // 立即保存助手消息
            saveMessage(responseMsg)

            // 2. 检查工具调用
            if let toolCalls = responseMsg.toolCalls, !toolCalls.isEmpty {
                if Self.verbose {
                    os_log("\(self.t)🔧 收到 \(toolCalls.count) 个工具调用，开始执行:")
                    for (index, tc) in toolCalls.enumerated() {
                        // 格式化参数显示（限制长度）
                        var argsPreview = tc.arguments
                        if argsPreview.count > 100 {
                            argsPreview = String(argsPreview.prefix(100)) + "..."
                        }
                        os_log("\(self.t)  \(index + 1). \(tc.name)(\(argsPreview))")
                    }
                }
                pendingToolCalls = toolCalls

                // 开始处理第一个工具
                let firstTool = pendingToolCalls.removeFirst()
                await handleToolCall(firstTool)
            } else {
                // 无工具调用，轮次结束
                isProcessing = false
                if Self.verbose {
                    os_log("\(self.t)✅ 对话轮次已完成（无工具调用）")
                }
            }
        } catch {
            errorMessage = error.localizedDescription
            messages.append(ChatMessage(role: .assistant, content: "Error: \(error.localizedDescription)", isError: true))
            isProcessing = false
            depthWarning = nil  // 清除深度警告
            os_log(.error, "\(self.t) 对话处理失败：\(error.localizedDescription)")
        }
    }

    // MARK: - 模式切换通知

    func notifyModeChangeToChat() async {
        let message: String
        switch languagePreference {
        case .chinese:
            message = "已切换到对话模式。在此模式下，我将只与您进行对话，不会执行任何工具或修改代码。有什么问题我可以帮您解答？"
        case .english:
            message = "Switched to Chat mode. In this mode, I will only chat with you without executing any tools or modifying code. How can I help you today?"
        }

        messages.append(ChatMessage(role: .assistant, content: message))
    }
}
