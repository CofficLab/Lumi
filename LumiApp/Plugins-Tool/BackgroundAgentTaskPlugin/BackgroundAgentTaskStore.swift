import Foundation
import SwiftData
import MagicKit

final class BackgroundAgentTaskStore: @unchecked Sendable {
    static let shared = BackgroundAgentTaskStore()

    private let container: ModelContainer
    private let queue = DispatchQueue(label: "BackgroundAgentTaskStore.queue", qos: .utility)

    private init() {
        let schema = Schema([
            BackgroundAgentTask.self
        ])

        let dbDir = AppConfig.getPluginDBFolderURL(pluginName: "BackgroundAgentTaskPlugin")
        let dbURL = dbDir.appendingPathComponent("BackgroundAgentTask.sqlite")

        let config = ModelConfiguration(
            schema: schema,
            url: dbURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )

        do {
            self.container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create BackgroundAgentTask ModelContainer: \(error)")
        }
    }

    func enqueue(prompt: String) -> UUID {
        let id = UUID()
        queue.async { [container] in
            let context = ModelContext(container)
            let task = BackgroundAgentTask(
                id: id,
                originalPrompt: prompt,
                statusRawValue: BackgroundAgentTaskStatus.pending.rawValue
            )
            context.insert(task)
            try? context.save()
        }

        Task.detached(priority: .utility) { [weak self] in
            await self?.runTask(id: id)
        }

        return id
    }

    func fetchRecent(limit: Int = 20) -> [BackgroundAgentTask] {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<BackgroundAgentTask>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }

    func fetchById(_ id: UUID) -> BackgroundAgentTask? {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<BackgroundAgentTask>(
            predicate: #Predicate { $0.id == id }
        )
        return (try? context.fetch(descriptor).first) ?? nil
    }

    private func updateTask(
        id: UUID,
        mutate: (BackgroundAgentTask) -> Void
    ) {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<BackgroundAgentTask>(
            predicate: #Predicate { $0.id == id }
        )
        guard let task = try? context.fetch(descriptor).first else { return }
        mutate(task)
        try? context.save()
    }

    private func runTask(id: UUID) async {
        updateTask(id: id) { task in
            task.startedAt = Date()
            task.statusRawValue = BackgroundAgentTaskStatus.running.rawValue
        }

        do {
            let config = makeCurrentLLMConfig()

            let llmService = LLMService()
            let toolService: ToolService = await MainActor.run {
                ToolService(llmService: llmService)
            }
            let toolExecutionService = ToolExecutionService(toolService: toolService)

            // 从数据库重新读取任务，确保拿到最新的 originalPrompt
            let context = ModelContext(container)
            let descriptor = FetchDescriptor<BackgroundAgentTask>(
                predicate: #Predicate { $0.id == id }
            )
            guard let task = try context.fetch(descriptor).first else {
                throw NSError(
                    domain: "BackgroundAgentTaskStore",
                    code: 404,
                    userInfo: [NSLocalizedDescriptionKey: "Task not found"]
                )
            }

            var messages: [ChatMessage] = [
                ChatMessage(role: .user, content: task.originalPrompt)
            ]

            let maxDepth = 16
            var finalReply: ChatMessage?

            toolLoop: for _ in 0..<maxDepth {
                let reply = try await llmService.sendMessage(
                    messages: messages,
                    config: config,
                    tools: toolService.tools
                )

                messages.append(reply)

                if let toolCalls = reply.toolCalls, !toolCalls.isEmpty {
                    for call in toolCalls {
                        let result: String
                        do {
                            result = try await toolExecutionService.executeTool(call)
                        } catch {
                            let errorMsg = toolExecutionService.createErrorMessage(for: call, error: error)
                            messages.append(errorMsg)
                            finalReply = errorMsg
                            break toolLoop
                        }

                        let toolMessage = ChatMessage(
                            role: .tool,
                            content: result,
                            toolCallID: call.id
                        )
                        messages.append(toolMessage)
                    }
                    continue
                } else {
                    finalReply = reply
                    break
                }
            }

            let summary: String
            if let final = finalReply {
                summary = final.content
            } else {
                summary = "后台任务已完成，但未获得模型回复。"
            }

            updateTask(id: id) { task in
                task.finishedAt = Date()
                task.statusRawValue = BackgroundAgentTaskStatus.succeeded.rawValue
                task.resultSummary = summary
                task.errorDescription = nil
            }
        } catch {
            updateTask(id: id) { task in
                task.finishedAt = Date()
                task.statusRawValue = BackgroundAgentTaskStatus.failed.rawValue
                task.errorDescription = error.localizedDescription
            }
        }
    }

    private func makeCurrentLLMConfig() -> LLMConfig {
        let registry = ProviderRegistry()
        LLMPluginsVM.registerAllProviders(to: registry)

        // 全局配置（与 ProjectVM.GlobalConfigKeys 保持一致）
        let globalProviderKey = "Agent_GlobalProviderId"
        let globalModelKey = "Agent_GlobalModel"

        let storedProviderId = AppSettingsStore.shared.string(forKey: globalProviderKey)
        let storedModel = AppSettingsStore.shared.string(forKey: globalModelKey)

        let providerId: String
        let model: String

        if let pid = storedProviderId, !pid.isEmpty,
           let m = storedModel, !m.isEmpty {
            providerId = pid
            model = m
        } else if let first = registry.providerTypes.first {
            providerId = first.id
            model = first.defaultModel
        } else {
            return .default
        }

        guard let providerType = registry.providerType(forId: providerId) else {
            return .default
        }

        let apiKey = AppSettingsStore.shared.string(forKey: providerType.apiKeyStorageKey) ?? ""

        return LLMConfig(
            apiKey: apiKey,
            model: model,
            providerId: providerId
        )
    }
}

