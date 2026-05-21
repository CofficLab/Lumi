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

// MARK: - Window Editor State

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
