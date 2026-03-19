import Combine
import Foundation
import MagicKit
import SwiftUI

/// 窗口状态模型
///
/// 每个窗口独立维护自己的状态，实现窗口级状态隔离
@MainActor
final class WindowState: ObservableObject, Identifiable, SuperLog {
    nonisolated static let emoji = "🪟"
    nonisolated static let verbose = false

    /// 窗口唯一标识
    let id: UUID

    /// 窗口标题
    @Published var title: String = "Lumi"

    /// 当前选中的会话 ID
    @Published var selectedConversationId: UUID?

    /// 当前关联的项目路径
    @Published var projectPath: String?

    /// 侧边栏可见性
    @Published var sidebarVisibility: Bool = true

    /// 导航分栏视图的列可见性状态
    @Published var columnVisibility: NavigationSplitViewVisibility = .automatic

    /// 当前应用模式
    @Published var selectedMode: AppMode = .agent

    /// 窗口是否活跃
    @Published var isActive: Bool = false

    /// 窗口创建时间
    let createdAt: Date

    /// Combine 订阅集合（用于外部监听）
    var cancellables = Set<AnyCancellable>()

    /// 初始化
    /// - Parameters:
    ///   - id: 窗口唯一标识，默认自动生成
    ///   - conversationId: 初始选中的会话 ID
    ///   - projectPath: 初始关联的项目路径
    init(
        id: UUID = UUID(),
        conversationId: UUID? = nil,
        projectPath: String? = nil
    ) {
        self.id = id
        self.selectedConversationId = conversationId
        self.projectPath = projectPath
        self.createdAt = Date()

        if Self.verbose {
            AppLogger.core.info("\(Self.t)创建窗口状态: \(id.uuidString.prefix(8))")
        }
    }

    /// 更新窗口标题
    func updateTitle(from conversation: Conversation?) {
        if let conversation = conversation {
            title = conversation.title
        } else if let path = projectPath {
            let url = URL(fileURLWithPath: path)
            title = "Lumi - \(url.lastPathComponent)"
        } else {
            title = "Lumi"
        }
    }

    /// 切换到指定会话
    func switchToConversation(_ conversationId: UUID?) {
        selectedConversationId = conversationId
        if Self.verbose {
            AppLogger.core.info("\(Self.t)窗口 \(self.id.uuidString.prefix(8)) 切换到会话: \(conversationId?.uuidString.prefix(8) ?? "nil")")
        }
    }

    /// 切换到指定项目
    func switchToProject(_ path: String?) {
        projectPath = path
        updateTitle(from: nil)
        if Self.verbose {
            let pathString = path ?? "nil"
            AppLogger.core.info("\(Self.t)窗口 \(self.id.uuidString.prefix(8)) 切换到项目: \(pathString)")
        }
    }

    /// 切换应用模式
    func switchMode(_ mode: AppMode) {
        selectedMode = mode
        if Self.verbose {
            let modeString = String(describing: mode)
            AppLogger.core.info("\(Self.t)窗口 \(self.id.uuidString.prefix(8)) 切换到模式: \(modeString)")
        }
    }

    /// 设置窗口活跃状态
    func setActive(_ active: Bool) {
        isActive = active
        if Self.verbose {
            AppLogger.core.info("\(Self.t)窗口 \(self.id.uuidString.prefix(8)) 活跃状态: \(active)")
        }
    }
}

// MARK: - Window State Container

/// 窗口状态容器（用于在视图中注入）
struct WindowStateKey: EnvironmentKey {
    static let defaultValue: WindowState? = nil
}

extension EnvironmentValues {
    var windowState: WindowState? {
        get { self[WindowStateKey.self] }
        set { self[WindowStateKey.self] = newValue }
    }
}

// MARK: - Window Events

/// 窗口间通信事件
enum WindowEvent {
    /// 会话列表变更
    case conversationListChanged
    /// 会话内容更新
    case conversationUpdated(UUID)
    /// 项目列表变更
    case projectListChanged
    /// 设置变更
    case settingsChanged
    /// 全局状态变更
    case globalStateChanged
}

// MARK: - Notification Extensions

extension Notification.Name {
    /// 窗口事件通知
    static let windowEvent = Notification.Name("windowEvent")
    /// 窗口激活通知
    static let windowActivated = Notification.Name("windowActivated")
    /// 窗口关闭通知
    static let windowClosed = Notification.Name("windowClosed")
}

extension NotificationCenter {
    /// 发送窗口事件
    static func postWindowEvent(_ event: WindowEvent, from windowId: UUID? = nil) {
        NotificationCenter.default.post(
            name: .windowEvent,
            object: windowId,
            userInfo: ["event": event]
        )
    }

    /// 发送窗口激活通知
    static func postWindowActivated(_ windowId: UUID) {
        NotificationCenter.default.post(
            name: .windowActivated,
            object: windowId
        )
    }

    /// 发送窗口关闭通知
    static func postWindowClosed(_ windowId: UUID) {
        NotificationCenter.default.post(
            name: .windowClosed,
            object: windowId
        )
    }
}
