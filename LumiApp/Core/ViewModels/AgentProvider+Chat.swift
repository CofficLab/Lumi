import Foundation
import SwiftUI
import AppKit
import OSLog
import MagicKit

// MARK: - 消息便捷方法（代理到 ConversationViewModel）

extension AgentProvider {
    /// 追加消息到列表
    func appendMessage(_ message: ChatMessage) {
        ConversationViewModel.shared.appendMessageInternal(message)
    }

    /// 插入消息到指定位置
    func insertMessage(_ message: ChatMessage, at index: Int) {
        ConversationViewModel.shared.insertMessageInternal(message, at: index)
    }

    /// 更新指定位置的消息
    func updateMessage(_ message: ChatMessage, at index: Int) {
        ConversationViewModel.shared.updateMessageInternal(message, at: index)
    }

    /// 设置聊天消息列表
    func setMessages(_ messages: [ChatMessage]) {
        ConversationViewModel.shared.setMessagesInternal(messages)
    }

    /// 设置当前会话
    func setCurrentConversation(_ conversation: Conversation?) {
        ConversationViewModel.shared.setCurrentConversationInternal(conversation)
    }

    /// 设置标题生成标记
    func setHasGeneratedTitle(_ value: Bool) {
        ConversationViewModel.shared.setHasGeneratedTitleInternal(value)
    }

    /// 加载指定对话的消息
    func loadConversation(_ conversationId: UUID) async {
        await ConversationViewModel.shared.loadConversation(conversationId)
    }

    /// 保存消息到存储
    func saveMessage(_ message: ChatMessage) {
        ConversationViewModel.shared.saveMessage(message)
    }
}

// MARK: - Cancel Support

extension AgentProvider {
    /// 取消当前正在进行的任务
    public func cancelCurrentTask() {
        if let task = currentTask {
            task.cancel()
            currentTask = nil
            os_log("\(Self.t)🛑 任务已取消")
        }
        // 清除工具队列
        pendingToolCalls.removeAll()
        setPermissionAndWarningState(permissionRequest: nil)
        // 重置处理状态
        setIsProcessing(false)
        // 添加取消提示消息
        let cancelMessage = languagePreference == .chinese ? "⚠️ 生成已取消" : "⚠️ Generation cancelled"
        appendMessage(ChatMessage(role: .assistant, content: cancelMessage))
    }

    // MARK: - SlashCommandService API

    public func appendSystemMessage(_ content: String) {
        appendMessage(ChatMessage(role: .assistant, content: content))
    }

    public func triggerPlanningMode(task: String) {
        Task {
            let planPrompt = await promptService.getPlanningModePrompt(task: task)
            await processUserMessage(input: planPrompt)
        }
    }
}

// MARK: - Message Sending & Processing

extension AgentProvider {
    // MARK: - 消息发送

    public func sendMessage() {
        guard !currentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !pendingAttachments.isEmpty else { return }

        if Self.verbose {
            os_log("\(Self.t) 用户发送消息")
        }

        // 清除之前的深度警告
        setPermissionAndWarningState(depthWarning: nil)

        // 检查是否已选择项目
        if !isProjectSelected {
            Task {
                let warningContent = await promptService.getProjectNotSelectedWarningMessage()
                let warningMsg = ChatMessage(
                    role: .assistant,
                    content: warningContent,
                    isError: true
                )
                appendMessage(warningMsg)
            }
            return
        }

        let input = currentInput
        setChatMessageState(input: "", processing: true, errorMessage: nil)

        // 检查是否为斜杠命令
        if input.hasPrefix("/") {
            Task {
                let result = await SlashCommandService.shared.handle(input: input, provider: self)
                switch result {
                case .handled:
                    setIsProcessing(false)
                    self.pendingAttachments.removeAll()
                case let .error(msg):
                    appendMessage(ChatMessage(role: .assistant, content: "Command Error: \(msg)", isError: true))
                    setIsProcessing(false)
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

    public func processUserMessage(input: String) async {
        let finalContent = input

        // 处理附件 - 转换为结构化图片数据
        var images: [ImageAttachment] = []
        if !pendingAttachments.isEmpty {
            if Self.verbose {
                os_log("\(Self.t)📎 处理 \(self.pendingAttachments.count) 个附件")
            }
            for attachment in pendingAttachments {
                if case .image(_, let data, let mimeType, _) = attachment {
                    images.append(ImageAttachment(data: data, mimeType: mimeType))
                    if Self.verbose {
                        os_log("\(Self.t) - 图片：\(mimeType), 大小：\(data.count) bytes")
                    }
                }
            }
            pendingAttachments.removeAll()
        } else if Self.verbose {
            os_log("\(Self.t)📎 无附件")
        }

        let userMsg = ChatMessage(role: .user, content: finalContent, images: images)

        if Self.verbose && !images.isEmpty {
            os_log("\(Self.t)✅ 用户消息包含 \(images.count) 张图片")
        }

        appendMessage(userMsg)

        // 立即保存用户消息
        saveMessage(userMsg)

        // 生成会话标题（如果是第一条用户消息）
        await generateTitleIfNeeded(userMessage: finalContent)

        await processTurn()
    }

    // MARK: - 对话轮次处理

    public func processTurn(depth: Int = 0) async {
        let maxDepth = 100

        guard depth < maxDepth else {
            setErrorMessage("Max recursion depth reached.")
            setIsProcessing(false)
            setPermissionAndWarningState(depthWarning: DepthWarning(currentDepth: depth, maxDepth: maxDepth, warningType: .reached))
            os_log(.error, "\(Self.t) 达到最大递归深度 (\(maxDepth))，对话终止")
            return
        }

        currentDepth = depth
        if Self.verbose {
            os_log("\(Self.t) 开始处理对话轮次 (深度：\(depth), 模式：\(self.chatMode.displayName))")
        }

        // 更新深度警告状态
        updateDepthWarning(currentDepth: depth, maxDepth: maxDepth)

        // 根据聊天模式决定是否传递工具
        let availableTools: [AgentTool] = (chatMode == .build) ? tools : []

        if Self.verbose && chatMode == .chat {
            os_log("\(Self.t) 当前为对话模式，不传递工具")
        }

        do {
            let config = getCurrentConfig()

            if Self.verbose {
                os_log("\(Self.t) 调用 LLM (供应商：\(config.providerId), 模型：\(config.model))")
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
                    os_log("%{public}@📝 为空内容消息生成工具摘要", Self.t)
                }
            }

            appendMessage(responseMsg)

            // 立即保存助手消息
            saveMessage(responseMsg)

            // 2. 检查工具调用
            if let toolCalls = responseMsg.toolCalls, !toolCalls.isEmpty {
                if Self.verbose {
                    os_log("\(Self.t)🔧 收到 \(toolCalls.count) 个工具调用，开始执行:")
                    for (index, tc) in toolCalls.enumerated() {
                        // 格式化参数显示（限制长度）
                        var argsPreview = tc.arguments
                        if argsPreview.count > 100 {
                            argsPreview = String(argsPreview.prefix(100)) + "..."
                        }
                        os_log("\(Self.t)  \(index + 1). \(tc.name)(\(argsPreview))")
                    }
                }
                pendingToolCalls = toolCalls

                // 开始处理第一个工具
                let firstTool = pendingToolCalls.removeFirst()
                await handleToolCall(firstTool)
            } else {
                // 无工具调用，轮次结束
                setIsProcessing(false)
                if Self.verbose {
                    os_log("\(Self.t)✅ 对话轮次已完成（无工具调用）")
                }
            }
        } catch {
            setErrorMessage(error.localizedDescription)
            appendMessage(ChatMessage(role: .assistant, content: "Error: \(error.localizedDescription)", isError: true))
            setIsProcessing(false)
            setPermissionAndWarningState(depthWarning: nil)
            os_log(.error, "\(Self.t) 对话处理失败：\(error.localizedDescription)")
        }
    }

    // MARK: - 模式切换通知

    public func notifyModeChangeToChat() async {
        let message: String
        switch languagePreference {
        case .chinese:
            message = "已切换到对话模式。在此模式下，我将只与您进行对话，不会执行任何工具或修改代码。有什么问题我可以帮您解答？"
        case .english:
            message = "Switched to Chat mode. In this mode, I will only chat with you without executing any tools or modifying code. How can I help you today?"
        }

        appendMessage(ChatMessage(role: .assistant, content: message))
    }
}

// MARK: - Tool Execution & Permission Handling

extension AgentProvider {
    // MARK: - 权限处理

    /// 解析工具调用参数
    private func parseArguments(_ argumentsString: String) -> [String: Any] {
        if let data = argumentsString.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return json
        }
        return [:]
    }

    public func respondToPermissionRequest(allowed: Bool) {
        guard let request = pendingPermissionRequest else { return }

        setPermissionAndWarningState(permissionRequest: nil)

        Task {
            if allowed {
                await executePendingTool(request: request)
            } else {
                appendMessage(ChatMessage(
                    role: .user,
                    content: "Tool execution denied by user.",
                    toolCallID: request.toolCallID
                ))
                await processPendingTools()
            }
        }
    }

    private func executePendingTool(request: PermissionRequest) async {
        // 使用 ToolManager 查找工具
        guard toolManager.hasTool(named: request.toolName) else {
            let errorMsg = ChatMessage(
                role: .user,
                content: "Error: Tool '\(request.toolName)' not found.",
                toolCallID: request.toolCallID
            )
            appendMessage(errorMsg)
            saveMessage(errorMsg)
            await processPendingTools()
            return
        }

        do {
            // 使用 ToolManager 执行工具
            let result = try await toolManager.executeTool(
                named: request.toolName,
                arguments: request.arguments
            )

            let resultMsg = ChatMessage(
                role: .user,
                content: result,
                toolCallID: request.toolCallID
            )
            appendMessage(resultMsg)
            saveMessage(resultMsg)

            await processPendingTools()
        } catch {
            let errorMsg = ChatMessage(
                role: .user,
                content: "Error executing tool: \(error.localizedDescription)",
                toolCallID: request.toolCallID
            )
            appendMessage(errorMsg)
            saveMessage(errorMsg)
            await processPendingTools()
        }
    }

    private func processPendingTools() async {
        if !pendingToolCalls.isEmpty {
            let nextTool = pendingToolCalls.removeFirst()
            if Self.verbose {
                os_log("\(Self.t) 继续处理下一个工具：\(nextTool.name)")
            }
            await handleToolCall(nextTool)
        } else {
            if Self.verbose {
                os_log("\(Self.t) 所有工具处理完成，继续对话")
            }
            await processTurn(depth: currentDepth + 1)
        }
    }

    // MARK: - 工具 Emoji 映射

    /// 获取工具对应的 emoji 图标
    func toolEmoji(for toolName: String) -> String {
        let emojiMap: [String: String] = [
            "read_file": "📖",
            "write_file": "✍️",
            "run_command": "⚡",
            "list_directory": "📁",
            "create_directory": "📂",
            "move_file": "📦",
            "search_files": "🔍",
            "get_file_info": "ℹ️",
            "bash": "⚡",
            "glob": "🔎",
            "edit": "✏️",
            "str_replace_editor": "✏️",
            "lsp": "💻",
            "goto_definition": "➡️",
            "find_references": "🔗",
            "document": "📚",
            "grep": "🔍"
        ]
        return emojiMap[toolName] ?? "🔧"
    }

    func handleToolCall(_ toolCall: ToolCall) async {
        if Self.verbose {
            os_log("\(Self.t)⚙️ 正在执行工具：\(toolCall.name)")
        }

        // 检查权限
        // 如果开启了自动批准，或者工具不需要权限
        let requiresPermission = PermissionService.shared.requiresPermission(toolName: toolCall.name, arguments: parseArguments(toolCall.arguments))

        if requiresPermission && !autoApproveRisk {
            if Self.verbose {
                os_log("\(Self.t)⚠️ 工具 \(toolCall.name) 需要权限批准")
            }
            // 评估命令风险
            let riskLevel: CommandRiskLevel

            if toolCall.name == "run_command" {
                let args = parseArguments(toolCall.arguments)
                if let command = args["command"] as? String {
                    riskLevel = PermissionService.shared.evaluateCommandRisk(command: command)
                } else {
                    // 默认中风险
                    riskLevel = .medium
                }
            } else {
                // 默认中风险
                riskLevel = .medium
            }

            setPermissionRequest(PermissionRequest(
                toolName: toolCall.name,
                argumentsString: toolCall.arguments,
                toolCallID: toolCall.id,
                riskLevel: riskLevel
            ))
            return
        }

        // 解析参数（确保 Sendable）
        let arguments: [String: AnySendable]
        if let data = toolCall.arguments.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            // 转换为 AnySendable 以确保线程安全
            arguments = json.mapValues { AnySendable(value: $0) }
        } else {
            arguments = [:]
        }

        // 使用 ToolManager 查找工具
        guard toolManager.hasTool(named: toolCall.name) else {
            os_log(.error, "\(Self.t)❌ 工具 '\(toolCall.name)' 未找到")
            let errorMsg = ChatMessage(
                role: .user,
                content: "Error: Tool '\(toolCall.name)' not found.",
                toolCallID: toolCall.id
            )
            appendMessage(errorMsg)
            saveMessage(errorMsg)
            await processPendingTools()
            return
        }

        do {
            let startTime = Date()

            // 在 async 调用前准备好参数
            // 将 arguments 数据复制到局部变量，避免在 async 上下文中捕获
            let toolArguments: [String: Any] = arguments.mapValues { $0.value }

            // 抑制数据竞争警告：toolArguments 是值类型，在 await 传递时已经完成复制
            // 这是安全的，因为 dictionary 在传递时被完整复制
            nonisolated(unsafe) let unsafeArgs = toolArguments

            // 使用 ToolManager 执行工具
            let result = try await toolManager.executeTool(
                named: toolCall.name,
                arguments: unsafeArgs
            )

            let _ = Date().timeIntervalSince(startTime)

            let resultMsg = ChatMessage(
                role: .user,
                content: result,
                toolCallID: toolCall.id
            )
            appendMessage(resultMsg)
            saveMessage(resultMsg)

            await processPendingTools()
        } catch {
            os_log(.error, "\(Self.t)❌ 工具执行失败：\(error.localizedDescription)")
            let errorMsg = ChatMessage(
                role: .user,
                content: "Error executing tool: \(error.localizedDescription)",
                toolCallID: toolCall.id
            )
            appendMessage(errorMsg)
            saveMessage(errorMsg)
            await processPendingTools()
        }
    }
}

// MARK: - Conversation Management

extension AgentProvider {
    /// 生成会话标题（如果是第一条用户消息）
    func generateTitleIfNeeded(userMessage: String) async {
        // 只在以下条件下生成标题：
        // 1. 尚未生成过标题
        // 2. 当前对话是初始标题 "新会话 "
        // 3. 消息内容非空
        guard !hasGeneratedTitle,
              let conversation = currentConversation,
              conversation.title.hasPrefix("新会话 "),
              !userMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        setHasGeneratedTitle(true)

        if Self.verbose {
            os_log("\(Self.t)🎯 开始为对话生成标题...")
        }

        // 获取当前 LLM 配置
        let config = getCurrentConfig()

        // 生成标题
        let title = await chatHistoryService.generateConversationTitle(
            from: userMessage,
            config: config
        )

        // 更新对话标题
        chatHistoryService.updateConversationTitle(conversation, newTitle: title)
        currentConversation?.title = title

        if Self.verbose {
            os_log("\(Self.t)✅ 对话标题已生成：\(title)")
        }
    }

    // MARK: - 历史记录管理

    public func clearHistory() {
        let languagePreference = self.languagePreference
        let isProjectSelected = self.isProjectSelected

        Task {
            let fullSystemPrompt = await promptService.buildSystemPrompt(
                languagePreference: languagePreference,
                includeContext: isProjectSelected
            )
            setMessages([ChatMessage(role: .system, content: fullSystemPrompt)])
        }
    }
}

// MARK: - Project Management

extension AgentProvider {
    // MARK: - 项目管理

    /// 切换到指定项目
    public func switchProjectWithPrompt(to path: String) {
        // 使用内核的 AgentProvider 执行实际的项目切换
        switchProject(to: path)

        // 更新本地状态（镜像 AgentProvider）
        let languagePreference = self.languagePreference

        Task {
            // 刷新系统提示
            let fullSystemPrompt = await promptService.buildSystemPrompt(
                languagePreference: languagePreference,
                includeContext: true
            )

            // 更新第一条系统消息
            let currentMessages = messages
            if !currentMessages.isEmpty, currentMessages[0].role == .system {
                updateMessage(ChatMessage(role: .system, content: fullSystemPrompt), at: 0)
            } else {
                insertMessage(ChatMessage(role: .system, content: fullSystemPrompt), at: 0)
            }

            // 添加切换项目通知（根据语言偏好）
            let projectName = self.currentProjectName
            let config = ProjectConfigStore.shared.getOrCreateConfig(for: path)
            let switchMessage: String
            switch languagePreference {
            case .chinese:
                switchMessage = """
                ✅ 已切换到项目

                **项目名称**: \(projectName)
                **项目路径**: \(path)
                **使用模型**: \(config.model.isEmpty ? "默认" : config.model) (\(config.providerId))
                """
            case .english:
                switchMessage = """
                ✅ Switched to project

                **Project**: \(projectName)
                **Path**: \(path)
                **Model**: \(config.model.isEmpty ? "Default" : config.model) (\(config.providerId))
                """
            }

            appendMessage(ChatMessage(role: .assistant, content: switchMessage))

            if Self.verbose {
                os_log("\(Self.t) 已切换到项目：\(projectName) (\(path))")
            }
        }
    }
}

// MARK: - Image Upload & Attachment Management

extension AgentProvider {
    // MARK: - 图片上传

    public func handleImageUpload(url: URL) {
        if Self.verbose {
            os_log("\(Self.t)📷 开始处理图片上传：\(url.lastPathComponent)")
        }

        // 读取图片数据
        guard let data = try? Data(contentsOf: url),
              let _ = NSImage(data: data) else {
            os_log(.error, "\(Self.t)❌ 无效的图片文件")
            setErrorMessage("Invalid image file")
            return
        }

        if Self.verbose {
            os_log("\(Self.t)✅ 图片读取成功，大小：\(data.count) bytes")
        }

        let mimeType = url.pathExtension.lowercased() == "png" ? "image/png" : "image/jpeg"

        // 添加到待发送附件列表
        pendingAttachments.append(.image(id: UUID(), data: data, mimeType: mimeType, url: url))

        if Self.verbose {
            os_log("\(Self.t)✅ 图片已添加到待发送列表，当前共 \(self.pendingAttachments.count) 个附件")
        }
    }

    public func removeAttachment(id: UUID) {
        pendingAttachments.removeAll { $0.id == id }
    }
}

// MARK: - Depth Warning Management

extension AgentProvider {
    // MARK: - 深度警告管理

    /// 更新深度警告状态
    func updateDepthWarning(currentDepth: Int, maxDepth: Int) {
        if currentDepth >= maxDepth - 1 {
            setPermissionAndWarningState(depthWarning: DepthWarning(currentDepth: currentDepth, maxDepth: maxDepth, warningType: .critical))
        } else if currentDepth >= maxDepth * 8 / 10 {
            setPermissionAndWarningState(depthWarning: DepthWarning(currentDepth: currentDepth, maxDepth: maxDepth, warningType: .approaching))
        } else {
            setPermissionAndWarningState(depthWarning: nil)
        }
    }

    /// 清除深度警告（用户手动关闭）
    public func dismissDepthWarning() {
        setPermissionAndWarningState(depthWarning: nil)
    }
}

// MARK: - Configuration Management

extension AgentProvider {
    // MARK: - 配置管理

    /// 更新选中供应商的模型
    public func updateSelectedModel(_ model: String) {
        guard let providerType = registry.providerType(forId: selectedProviderId) else {
            return
        }
        UserDefaults.standard.set(model, forKey: providerType.modelStorageKey)
        if Self.verbose {
            os_log("\(Self.t) 更新模型：\(providerType.displayName) -> \(model)")
        }
    }

    /// 保存当前模型到项目配置
    public func saveCurrentModelToProjectConfig() {
        guard isProjectSelected, !currentProjectPath.isEmpty else {
            return
        }

        // 获取或创建项目配置
        let config = ProjectConfigStore.shared.getOrCreateConfig(for: currentProjectPath)

        // 更新配置
        var updatedConfig = config
        updatedConfig.providerId = selectedProviderId
        updatedConfig.model = currentModel

        // 保存
        ProjectConfigStore.shared.saveConfig(updatedConfig)

        if Self.verbose {
            os_log("\(Self.t) 保存模型到项目配置：\(self.currentProjectName) -> \(self.currentModel)")
        }
    }
}
