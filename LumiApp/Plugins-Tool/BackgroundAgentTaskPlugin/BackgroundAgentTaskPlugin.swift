import Foundation
import SwiftUI
import MagicKit
import os

actor BackgroundAgentTaskPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.background-agent-task")
    nonisolated static let emoji = "🧵"
    nonisolated static let verbose = false

    static let id: String = "BackgroundAgentTaskPlugin"
    static let displayName: String = "后台 Agent 任务"
    static let description: String = "接收指令并在后台异步执行任务，任务结果存储在插件自有数据库中。"
    static let iconName: String = "clock.arrow.circlepath"
    static let isConfigurable: Bool = false
    static let enable: Bool = true
    static var order: Int { 96 }

    nonisolated var instanceLabel: String {
        Self.id
    }

    static let shared = BackgroundAgentTaskPlugin()

    nonisolated func onRegister() {}
    nonisolated func onEnable() {}
    nonisolated func onDisable() {}

    @MainActor
    func agentToolFactories() -> [AnyAgentToolFactory] {
        [AnyAgentToolFactory(BackgroundAgentTaskToolFactory())]
    }

    @MainActor
    func addStatusBarView() -> AnyView? {
        AnyView(BackgroundAgentTaskStatusBarView())
    }
}

@MainActor
private struct BackgroundAgentTaskToolFactory: AgentToolFactory {
    let id: String = "background.agent.task.factory"
    let order: Int = 0

    func makeTools(env: AgentToolEnvironment) -> [AgentTool] {
        [
            CreateBackgroundAgentTaskTool(),
            ListBackgroundAgentTasksTool(),
            GetBackgroundAgentTaskDetailTool()
        ]
    }
}

