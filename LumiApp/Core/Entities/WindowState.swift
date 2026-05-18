import Combine
import Foundation
import MagicKit
import SwiftUI

/// 窗口活动面板类型
///
/// 标识当前窗口正在显示的主要内容类型
enum WindowActivePanel: String, Codable, Hashable {
    /// 聊天面板
    case chat
    /// 编辑器面板
    case editor
    /// 项目文件树
    case fileTree
    /// 终端
    case terminal
    /// 设置（全局单例）
    case settings
    /// 欢迎页面
    case welcome
}

/// 窗口级编辑器状态
///
/// 每个窗口独立维护的编辑器状态
struct WindowEditorState: Codable, Hashable {
    /// 当前打开的文件路径列表
    var openFileURLs: [URL] = []
    /// 当前活跃的文件 URL
    var activeFileURL: URL?
    /// 编辑器分栏数量
    var splitCount: Int = 1
    
    /// 是否有打开的文件
    var hasOpenFiles: Bool {
        !openFileURLs.isEmpty
    }
}

/// 窗口状态模型
///
/// 每个窗口独立维护自己的状态，实现窗口级状态隔离。
/// 包含会话、项目、编辑器、布局等窗口级状态。
@MainActor
final class WindowState: ObservableObject, Identifiable, SuperLog {
    nonisolated static let emoji = "🪟"
    nonisolated static let verbose: Bool = false
    
    // MARK: - Core Identity
    
    /// 窗口唯一标识
    let id: UUID
    
    /// 窗口标题
    @Published var title: String = "Lumi"
    
    /// 窗口创建时间
    let createdAt: Date
    
    // MARK: - Window-Level Session State
    
    /// 当前选中的会话 ID
    @Published var selectedConversationId: UUID?
    
    // MARK: - Window-Level Project State
    
    /// 当前关联的项目路径
    @Published var projectPath: String?
    
    /// 当前项目名称（从 projectPath 派生）
    var projectName: String? {
        guard let path = projectPath else { return nil }
        return URL(fileURLWithPath: path).lastPathComponent
    }
    
    // MARK: - Window-Level Editor State
    
    /// 当前活跃的面板类型
    @Published var activePanel: WindowActivePanel = .chat
    
    /// 窗口级编辑器状态
    @Published var editorState: WindowEditorState = WindowEditorState()
    
    // MARK: - Layout State
    
    /// 侧边栏可见性
    @Published var sidebarVisibility: Bool = true
    
    /// 导航分栏视图的列可见性状态
    @Published var columnVisibility: NavigationSplitViewVisibility = .automatic
    
    // MARK: - Window Status
    
    /// 窗口是否活跃
    @Published var isActive: Bool = false
    
    /// Combine 订阅集合（用于外部监听）
    var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
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
        
        // 根据初始参数设置活跃面板
        if conversationId != nil {
            self.activePanel = .chat
        } else if projectPath != nil {
            self.activePanel = .fileTree
        }
        
        if Self.verbose {
            AppLogger.core.info("\(Self.t)创建窗口状态: \(id.uuidString.prefix(8))")
        }
    }
    
    // MARK: - Convenience Init from Route
    
    /// 从窗口路由创建状态
    /// - Parameter route: 窗口路由
    convenience init(route: LumiWindowRoute) {
        self.init(
            id: route.id,
            conversationId: route.conversationId,
            projectPath: route.projectPath
        )
    }
    
    // MARK: - Conversation Management
    
    /// 切换到指定会话
    /// - Parameter conversationId: 会话 ID，nil 表示清除选择
    func switchToConversation(_ conversationId: UUID?) {
        let oldId = selectedConversationId
        selectedConversationId = conversationId
        
        // 切换到会话时自动激活聊天面板
        if conversationId != nil {
            activePanel = .chat
        }
        
        if Self.verbose && oldId != conversationId {
            AppLogger.core.info("\(Self.t)窗口 \(self.id.uuidString.prefix(8)) 切换到会话: \(conversationId?.uuidString.prefix(8) ?? "nil")")
        }
    }
    
    // MARK: - Project Management
    
    /// 切换到指定项目
    /// - Parameter path: 项目路径，nil 表示清除项目
    func switchToProject(_ path: String?) {
        let oldPath = projectPath
        projectPath = path
        
        // 切换项目时更新标题
        updateTitleFromProject()
        
        // 切换到项目时自动激活文件树面板
        if path != nil && activePanel == .welcome {
            activePanel = .fileTree
        }
        
        if Self.verbose && oldPath != path {
            let pathString = path ?? "nil"
            AppLogger.core.info("\(Self.t)窗口 \(self.id.uuidString.prefix(8)) 切换到项目: \(pathString)")
        }
    }
    
    // MARK: - Editor State Management
    
    /// 打开文件到编辑器
    /// - Parameter url: 文件 URL
    func openFile(_ url: URL) {
        // 避免重复添加
        if !editorState.openFileURLs.contains(url) {
            editorState.openFileURLs.append(url)
        }
        editorState.activeFileURL = url
        activePanel = .editor
        
        if Self.verbose {
            AppLogger.core.info("\(Self.t)窗口 \(self.id.uuidString.prefix(8)) 打开文件: \(url.lastPathComponent)")
        }
    }
    
    /// 关闭文件
    /// - Parameter url: 文件 URL
    func closeFile(_ url: URL) {
        editorState.openFileURLs.removeAll { $0 == url }
        
        // 如果关闭的是当前活跃文件，切换到下一个
        if editorState.activeFileURL == url {
            editorState.activeFileURL = editorState.openFileURLs.last
        }
        
        // 如果没有打开的文件，切换回之前的面板
        if !editorState.hasOpenFiles {
            activePanel = projectPath != nil ? .fileTree : .chat
        }
        
        if Self.verbose {
            AppLogger.core.info("\(Self.t)窗口 \(self.id.uuidString.prefix(8)) 关闭文件: \(url.lastPathComponent)")
        }
    }
    
    /// 切换到指定文件
    /// - Parameter url: 文件 URL
    func switchToFile(_ url: URL) {
        guard editorState.openFileURLs.contains(url) else { return }
        editorState.activeFileURL = url
        activePanel = .editor
        
        if Self.verbose {
            AppLogger.core.info("\(Self.t)窗口 \(self.id.uuidString.prefix(8)) 切换到文件: \(url.lastPathComponent)")
        }
    }
    
    // MARK: - Title Management
    
    /// 根据当前状态更新窗口标题
    func updateTitle() {
        // 优先级：会话标题 > 项目名 > 默认
        if let conversationId = selectedConversationId {
            // 会话标题由外部设置（通过 updateTitle(from:)）
            // 这里保持现有标题或使用 ID
            if title == "Lumi" {
                title = "Lumi - \(conversationId.uuidString.prefix(8))"
            }
        } else {
            updateTitleFromProject()
        }
    }
    
    /// 从项目路径更新标题
    private func updateTitleFromProject() {
        if let path = projectPath {
            let url = URL(fileURLWithPath: path)
            title = "Lumi - \(url.lastPathComponent)"
        } else {
            title = "Lumi"
        }
    }
    
    /// 更新窗口标题（从会话对象）
    /// - Parameter conversation: 会话对象
    func updateTitle(from conversation: Conversation?) {
        if let conversation = conversation {
            title = conversation.title
        } else {
            updateTitleFromProject()
        }
    }
    
    // MARK: - Window Status
    
    /// 设置窗口活跃状态
    /// - Parameter active: 是否活跃
    func setActive(_ active: Bool) {
        let wasActive = isActive
        isActive = active
        
        if Self.verbose && wasActive != active {
            AppLogger.core.info("\(Self.t)窗口 \(self.id.uuidString.prefix(8)) 活跃状态: \(active)")
        }
    }
    
    // MARK: - Snapshot
    
    /// 获取当前状态快照（用于持久化或调试）
    func snapshot() -> WindowStateSnapshot {
        WindowStateSnapshot(
            windowId: id,
            conversationId: selectedConversationId,
            projectPath: projectPath,
            activePanel: activePanel,
            editorState: editorState,
            sidebarVisibility: sidebarVisibility,
            createdAt: createdAt
        )
    }
}

/// 窗口状态快照（用于持久化）
struct WindowStateSnapshot: Codable {
    let windowId: UUID
    let conversationId: UUID?
    let projectPath: String?
    let activePanel: WindowActivePanel
    let editorState: WindowEditorState
    let sidebarVisibility: Bool
    let createdAt: Date
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
