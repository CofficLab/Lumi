import Foundation
import os
import SwiftUI
import SuperLogKit
import LumiCoreKit

private final class NotificationObserverHolder: @unchecked Sendable {
    private var observer: NSObjectProtocol?

    var hasObserver: Bool {
        observer != nil
    }

    deinit {
        remove()
    }

    func set(_ observer: NSObjectProtocol) {
        remove()
        self.observer = observer
    }

    func remove() {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
            self.observer = nil
        }
    }
}

public protocol SidebarServicing: Sendable {
    func fetchTasks(conversationId: String) async -> [TaskItem]
    func getProgressSummary(conversationId: String) async -> TaskProgressSummary
}

extension TaskStateManager: SidebarServicing {}

/// 右侧栏视图模型
///
/// 负责获取并展示当前会话的任务列表。
/// 通过监听任务变更通知自动刷新 UI。
@MainActor
final public class SidebarViewModel: ObservableObject, SuperLog {
    nonisolated public static let emoji = "📋"
    nonisolated public static let verbose = false
    nonisolated public static let logger = Logger(subsystem: "com.coffic.lumi", category: "autotask.sidebar.vm")

    @Published public var tasks: [TaskDisplayItem] = []
    @Published public var summary: TaskProgressSummary?
    @Published public var isLoading: Bool = false

    public var currentConversationId: String?
    private nonisolated let notificationObserverHolder = NotificationObserverHolder()
    private let service: any SidebarServicing
    private var refreshGeneration: Int = 0

    public init(service: (any SidebarServicing)? = nil) {
        // 默认从插件的 lifecycle-managed manager 取；
        // 调用方可在测试或特殊场景下传入自定义实现。
        self.service = service ?? AutoTaskPlugin.manager ?? DefaultSidebarService()
    }

    deinit {
        notificationObserverHolder.remove()
    }

    public func removeObserver() {
        notificationObserverHolder.remove()
    }

    /// 刷新当前会话的任务列表
    public func refresh(conversationId: String?) async {
        refreshGeneration += 1
        let generation = refreshGeneration

        guard let conversationId else {
            tasks = []
            summary = nil
            currentConversationId = nil
            isLoading = false
            return
        }

        let cid = conversationId
        let conversationChanged = currentConversationId != cid
        currentConversationId = cid

        // 首次绑定通知（仅一次）
        if !notificationObserverHolder.hasObserver {
            if Self.verbose {
                Self.logger.info("\(Self.t)Registering taskDidChange observer")
            }
            let observer = NotificationCenter.default.addObserver(
                forName: .taskDidChange,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                let changedCid = notification.userInfo?["conversationId"] as? String
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if let changedCid, changedCid == self.currentConversationId {
                        await self.reloadCurrentConversationFromDB()
                    }
                }
            }
            notificationObserverHolder.set(observer)
        }

        // 会话切换或任务变更时都刷新
        if conversationChanged {
            isLoading = true
        }
        await reloadFromDB(conversationId: cid, generation: generation)
        if conversationChanged && isCurrentRefresh(generation, conversationId: cid) {
            isLoading = false
        }
    }

    /// 手动刷新（用于外部事件触发）
    public func forceRefresh() async {
        guard let cid = currentConversationId else {
            Self.logger.warning("\(Self.t)forceRefresh: currentConversationId is nil, skip")
            return
        }
        refreshGeneration += 1
        await reloadFromDB(conversationId: cid, generation: refreshGeneration)
    }

    // MARK: - Private

    private func reloadCurrentConversationFromDB() async {
        guard let cid = currentConversationId else { return }
        refreshGeneration += 1
        await reloadFromDB(conversationId: cid, generation: refreshGeneration)
    }

    private func reloadFromDB(conversationId cid: String, generation: Int) async {
        let fetchedTasks = await service.fetchTasks(conversationId: cid)
        let fetchedSummary = await service.getProgressSummary(conversationId: cid)

        guard isCurrentRefresh(generation, conversationId: cid) else { return }

        if Self.verbose {
            Self.logger.info("\(Self.t)reloadFromDB: cid=\(cid.prefix(8)), tasks=\(fetchedTasks.count), summary=\(fetchedSummary.total) total")
        }

        tasks = fetchedTasks.map { TaskDisplayItem(from: $0) }
        summary = fetchedSummary
    }

    private func isCurrentRefresh(_ generation: Int, conversationId: String) -> Bool {
        refreshGeneration == generation && currentConversationId == conversationId
    }
}

/// 任务展示用模型
public struct TaskDisplayItem: Identifiable, Equatable {
    public let id: String
    public let title: String
    public let detail: String?
    public let status: TaskItem.TaskStatus
    public let order: Int

    public var statusSystemImage: String {
        switch status {
        case .pending: "circle"
        case .inProgress: "arrow.triangle.2.circlepath"
        case .completed: "checkmark.circle.fill"
        case .skipped: "forward.circle"
        }
    }

    public var statusColor: Color {
        switch status {
        case .pending: .secondary
        case .inProgress: .blue
        case .completed: .green
        case .skipped: .orange
        }
    }

    public var statusText: String {
        switch status {
        case .pending: LumiPluginLocalization.string("Pending", bundle: .module)
        case .inProgress: LumiPluginLocalization.string("In Progress", bundle: .module)
        case .completed: LumiPluginLocalization.string("Completed", bundle: .module)
        case .skipped: LumiPluginLocalization.string("Skipped", bundle: .module)
        }
    }
}

extension TaskDisplayItem {
    public init(from task: TaskItem) {
        self.id = task.id
        self.title = task.title
        self.detail = task.detail
        self.status = task.status
        self.order = task.order
    }
}

/// 默认空实现：当 `AutoTaskPlugin.manager` 未初始化时使用，
/// 保证 ViewModel 在 manager 缺失时仍可构造（仅返回空数据）。
private struct DefaultSidebarService: SidebarServicing {
    func fetchTasks(conversationId: String) async -> [TaskItem] { [] }
    func getProgressSummary(conversationId: String) async -> TaskProgressSummary {
        TaskProgressSummary(total: 0, completed: 0, inProgress: 0, pending: 0, skipped: 0)
    }
}
