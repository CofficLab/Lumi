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

    // MARK: - 协调器状态

    private var worker: BackgroundAgentTaskWorker?
    private nonisolated(unsafe) var taskCreationObserver: NSObjectProtocol?

    // MARK: - 插件生命周期

    nonisolated func onRegister() {
        if Self.verbose {
            Self.logger.info("BackgroundAgentTaskPlugin 注册")
        }
    }

    nonisolated func onEnable() {
        Task { [weak self] in
            await self?.startWorker()
            await self?.setupEventObservers()
        }

        if Self.verbose {
            Self.logger.info("BackgroundAgentTaskPlugin 启用")
        }
    }

    nonisolated func onDisable() {
        Task { [weak self] in
            await self?.stopWorker()
            await self?.removeEventObservers()
        }

        if Self.verbose {
            Self.logger.info("BackgroundAgentTaskPlugin 禁用")
        }
    }

    // MARK: - Worker 管理

    /// 启动 Worker
    private func startWorker() async {
        guard worker == nil else { return }

        let newWorker = BackgroundAgentTaskWorker()
        await newWorker.start()
        worker = newWorker

        if Self.verbose {
            Self.logger.info("\(self.t) Worker 已启动")
        }
    }

    /// 停止 Worker
    private func stopWorker() async {
        await worker?.stop()
        worker = nil

        if Self.verbose {
            Self.logger.info("\(self.t) Worker 已停止")
        }
    }

    // MARK: - 事件监听

    /// 设置事件监听（插件作为协调器）
    private func setupEventObservers() async {
        await MainActor.run { [weak self] in
            guard let self = self else { return }

            // 监听任务创建事件
            self.taskCreationObserver = NotificationCenter.default.addObserver(
                forName: .backgroundAgentTaskDidCreate,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let self = self else { return }

                if Self.verbose {
                    if let userInfo = notification.userInfo,
                       let taskIdString = userInfo["taskId"] as? String {
                        Self.logger.info("\(self.t) 收到任务创建事件: \(taskIdString)")
                    }
                }

                // 通知 Worker 有新任务
                Task {
                    await self.worker?.taskDidCreate()
                }
            }
        }

        if Self.verbose {
            Self.logger.info("\(self.t) 事件监听已设置")
        }
    }

    /// 移除事件监听
    private func removeEventObservers() async {
        await MainActor.run { [weak self] in
            guard let self = self else { return }

            if let observer = self.taskCreationObserver {
                NotificationCenter.default.removeObserver(observer)
                self.taskCreationObserver = nil
            }
        }

        if Self.verbose {
            Self.logger.info("\(self.t) 事件监听已移除")
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
