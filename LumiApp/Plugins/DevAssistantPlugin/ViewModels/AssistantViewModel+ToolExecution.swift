import Foundation
import MagicKit
import OSLog

// MARK: - 工具执行与权限处理

extension AssistantViewModel {
    // MARK: - 权限处理

    /// 解析工具调用参数
    private func parseArguments(_ argumentsString: String) -> [String: Any] {
        if let data = argumentsString.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return json
        }
        return [:]
    }

    func respondToPermissionRequest(allowed: Bool) {
        guard let request = pendingPermissionRequest else { return }

        pendingPermissionRequest = nil

        Task {
            if allowed {
                await executePendingTool(request: request)
            } else {
                messages.append(ChatMessage(
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
            messages.append(errorMsg)
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
            messages.append(resultMsg)
            saveMessage(resultMsg)

            await processPendingTools()
        } catch {
            let errorMsg = ChatMessage(
                role: .user,
                content: "Error executing tool: \(error.localizedDescription)",
                toolCallID: request.toolCallID
            )
            messages.append(errorMsg)
            saveMessage(errorMsg)
            await processPendingTools()
        }
    }

    private func processPendingTools() async {
        if !pendingToolCalls.isEmpty {
            let nextTool = pendingToolCalls.removeFirst()
            if Self.verbose {
                os_log("\(self.t) 继续处理下一个工具：\(nextTool.name)")
            }
            await handleToolCall(nextTool)
        } else {
            if Self.verbose {
                os_log("\(self.t) 所有工具处理完成，继续对话")
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
            os_log("\(self.t)⚙️ 正在执行工具：\(toolCall.name)")
        }

        // 检查权限
        // 如果开启了自动批准，或者工具不需要权限
        let requiresPermission = PermissionService.shared.requiresPermission(toolName: toolCall.name, arguments: parseArguments(toolCall.arguments))

        if requiresPermission && !autoApproveRisk {
            if Self.verbose {
                os_log("\(self.t)⚠️ 工具 \(toolCall.name) 需要权限批准")
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

            pendingPermissionRequest = PermissionRequest(
                toolName: toolCall.name,
                argumentsString: toolCall.arguments,
                toolCallID: toolCall.id,
                riskLevel: riskLevel
            )
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
            os_log(.error, "\(self.t)❌ 工具 '\(toolCall.name)' 未找到")
            let errorMsg = ChatMessage(
                role: .user,
                content: "Error: Tool '\(toolCall.name)' not found.",
                toolCallID: toolCall.id
            )
            messages.append(errorMsg)
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

            let duration = Date().timeIntervalSince(startTime)

            let resultMsg = ChatMessage(
                role: .user,
                content: result,
                toolCallID: toolCall.id
            )
            messages.append(resultMsg)
            saveMessage(resultMsg)

            await processPendingTools()
        } catch {
            os_log(.error, "\(self.t)❌ 工具执行失败：\(error.localizedDescription)")
            let errorMsg = ChatMessage(
                role: .user,
                content: "Error executing tool: \(error.localizedDescription)",
                toolCallID: toolCall.id
            )
            messages.append(errorMsg)
            saveMessage(errorMsg)
            await processPendingTools()
        }
    }
}
