import SwiftUI
import MagicKit
import os

actor BackgroundAgentTaskPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.background-agent-task")
    nonisolated static let emoji = "🧵"
    nonisolated static let verbose = false

    static let id: String = "BackgroundAgentTaskPlugin"
    static let displayName: String = String(localized: "后台 Agent 任务", table: "BackgroundAgentTask")
    static let description: String = String(localized: "接收指令并在后台异步执行任务，任务结果存储在插件自有数据库中。", table: "BackgroundAgentTask")
    static let iconName: String = "clock.arrow.circlepath"
    static let isConfigurable: Bool = false
    static let enable: Bool = true
    static var order: Int { 96 }

    nonisolated var instanceLabel: String {
        Self.id
    }

    static let shared = BackgroundAgentTaskPlugin()

    // MARK: - 插件属性

    private var worker: BackgroundAgentTaskWorker?
    private var observationTask: Task<Void, Never>?

    // MARK: - 插件生命周期

    nonisolated func onRegister() {
        // 插件注册时初始化
        if Self.verbose {
            Self.logger.info("BackgroundAgentTaskPlugin 注册")
        }
    }

    nonisolated func onEnable() {
        // 插件启用时启动 Worker 和监听
        Task { [weak self] in
            await self?.setupWorkerAndObserver()
        }

        if Self.verbose {
            Self.logger.info("BackgroundAgentTaskPlugin 启用")
        }
    }

    nonisolated func onDisable() {
        // 插件禁用时停止 Worker 和监听
        Task { [weak self] in
            await self?.teardownWorkerAndObserver()
        }

        if Self.verbose {
            Self.logger.info("BackgroundAgentTaskPlugin 禁用")
        }
    }

    // MARK: - 协调器逻辑

    /// 设置 Worker 和事件监听
    private func setupWorkerAndObserver() async {
        // 1. 启动 Worker
        let newWorker = BackgroundAgentTaskWorker(store: BackgroundAgentTaskStore.shared)
        await newWorker.start()
        self.worker = newWorker

        if Self.verbose {
            Self.logger.info("\(self.t) Worker 已启动")
        }

        // 2. 监听任务创建事件（即时触发）
        await observeTaskCreation()

        if Self.verbose {
            Self.logger.info("\(self.t) 事件监听已启动")
        }
    }

    /// 清理 Worker 和事件监听
    private func teardownWorkerAndObserver() async {
        // 1. 停止监听
        observationTask?.cancel()
        observationTask = nil

        // 2. 停止 Worker
        await worker?.stop()
        worker = nil

        if Self.verbose {
            Self.logger.info("\(self.t) Worker 已停止")
        }
    }

    /// 监听任务创建事件
    private func observeTaskCreation() async {
        observationTask = Task { @MainActor in
            NotificationCenter.default.addObserver(
                forName: .backgroundAgentTaskDidCreate,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let self = self else { return }

                guard let userInfo = notification.userInfo,
                      let taskIdString = userInfo["taskId"] as? String,
                      let taskId = UUID(uuidString: taskIdString) else {
                    return
                }

                if Self.verbose {
                    Self.logger.info("\(self.t) 收到任务创建事件: \(taskId)")
                }

                // 立即通知 Worker 尝试获取任务
                // 注意：这里我们只是唤醒 Worker，具体获取由 Worker 自己负责
                Task {
                    // Worker 会在下次循环中自动获取任务
                    // 如果需要更快的响应，可以在这里添加额外的唤醒逻辑
                }
            }
        }
    }

    // MARK: - Agent 工具

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
            ListBackgroundTasksTool(),
            GetBackgroundTaskDetailTool()
        ]
    }
}
