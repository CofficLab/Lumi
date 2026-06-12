import Foundation
import LumiCoreKit
import SuperLogKit
import os

/// 子智能体执行引擎：管理并行子智能体生命周期。
public actor SubAgentRunner: SuperLog {
    public nonisolated static let emoji = "🤖"

    public static let shared = SubAgentRunner()

    private var activeAgents: [String: SubAgentContext] = [:]
    private let maxConcurrency = 5

    private init() {}

    public func spawn(
        task: String,
        description: String,
        providerId: String,
        modelId: String
    ) throws -> String {
        let runningCount = activeAgents.values.filter { $0.status == .running }.count
        guard runningCount < maxConcurrency else {
            throw SubAgentError.concurrentLimit(maxConcurrency)
        }

        let agentId = UUID().uuidString
        let context = SubAgentContext(
            agentId: agentId,
            description: description,
            providerId: providerId,
            modelId: modelId,
            task: task
        )

        activeAgents[agentId] = context
        context.status = .failed
        context.result = SubAgentResult(
            agentId: agentId,
            status: .failed,
            result: "Sub-agent execution is not yet wired to the new Lumi chat runtime.",
            providerId: providerId,
            modelId: modelId,
            duration: 0
        )

        MultiAgentPlugin.logger.info("\(Self.t)子智能体已创建：\(agentId.prefix(8)) (\(providerId)/\(modelId))")

        return agentId
    }

    public func collect(agentIds: [String], timeout: TimeInterval = 120) async -> [SubAgentResult] {
        let startTime = Date()

        while Date().timeIntervalSince(startTime) < timeout {
            let allDone = agentIds.allSatisfy { id in
                if let ctx = activeAgents[id] {
                    return ctx.status != .running
                }
                return true
            }

            if allDone { break }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }

        var results: [SubAgentResult] = []

        for agentId in agentIds {
            guard let ctx = activeAgents[agentId] else {
                results.append(SubAgentResult(
                    agentId: agentId,
                    status: .failed,
                    result: "Agent not found: \(agentId)",
                    providerId: "",
                    modelId: "",
                    duration: 0
                ))
                continue
            }

            if let result = ctx.result {
                results.append(result)
            } else if ctx.status == .running {
                ctx.taskHandle?.cancel()
                ctx.status = .cancelled
                let duration = Date().timeIntervalSince(ctx.createdAt)
                let timeoutResult = SubAgentResult(
                    agentId: agentId,
                    status: .cancelled,
                    result: "Agent timed out after \(Int(timeout))s",
                    providerId: ctx.providerId,
                    modelId: ctx.modelId,
                    duration: duration
                )
                ctx.result = timeoutResult
                results.append(timeoutResult)
            }
        }

        for agentId in agentIds {
            activeAgents.removeValue(forKey: agentId)
        }

        return results
    }

    public func cancelAll() {
        for (_, ctx) in activeAgents {
            ctx.taskHandle?.cancel()
            if ctx.status == .running {
                ctx.status = .cancelled
            }
        }
        activeAgents.removeAll()
    }

    public func activeCount() -> Int {
        activeAgents.values.filter { $0.status == .running }.count
    }
}
