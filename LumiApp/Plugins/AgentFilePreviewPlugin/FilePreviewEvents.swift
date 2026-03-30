import SwiftUI
import Foundation
import CodeEditor

// MARK: - Notification Extension

extension Notification.Name {
    /// 文件预览主题已更改的通知
    /// object: nil
    /// userInfo: ["theme": String] - 主题的 rawValue
    static let filePreviewThemeDidChange = Notification.Name("FilePreviewThemeDidChange")

    /// 文件内容已保存的通知
    /// object: URL (保存的文件 URL)
    /// userInfo: ["success": Bool, "error": String?] - 保存结果和错误信息
    static let fileContentSaved = Notification.Name("FileContentSaved")

    /// 文件预览模式已更改的通知
    /// object: nil
    /// userInfo: ["isReadOnly": Bool, "isTruncated": Bool] - 预览模式状态
    static let filePreviewModeChanged = Notification.Name("FilePreviewModeChanged")

    /// 文本选择已更改的通知（文件预览特有的代码选择）
    /// object: nil
    /// userInfo: ["selection": CodeSelectionRange?] - 代码选区信息
    static let filePreviewTextSelectionChanged = Notification.Name("FilePreviewTextSelectionChanged")
}

// MARK: - NotificationCenter Extension

extension NotificationCenter {
    /// 发送文件预览主题已更改的通知
    /// 自动在主线程发送通知
    /// - Parameter theme: 主题名称
    static func postFilePreviewThemeDidChange(theme: CodeEditor.ThemeName) {
        Task { @MainActor in
            NotificationCenter.default.post(
                name: .filePreviewThemeDidChange,
                object: nil,
                userInfo: ["theme": theme.rawValue]
            )
        }
    }

    /// 发送文件内容已保存的通知
    /// 自动在主线程发送通知
    /// - Parameters:
    ///   - fileURL: 保存的文件 URL
    ///   - success: 是否成功
    ///   - error: 错误信息（如果失败）
    static func postFileContentSaved(fileURL: URL, success: Bool, error: String? = nil) {
        Task { @MainActor in
            var userInfo: [String: Any] = ["success": success]
            if let error = error {
                userInfo["error"] = error
            }
            NotificationCenter.default.post(
                name: .fileContentSaved,
                object: fileURL,
                userInfo: userInfo
            )
        }
    }

    /// 发送文件预览模式已更改的通知
    /// 自动在主线程发送通知
    /// - Parameters:
    ///   - isReadOnly: 是否为只读模式
    ///   - isTruncated: 是否为截断模式
    static func postFilePreviewModeChanged(isReadOnly: Bool, isTruncated: Bool) {
        Task { @MainActor in
            NotificationCenter.default.post(
                name: .filePreviewModeChanged,
                object: nil,
                userInfo: [
                    "isReadOnly": isReadOnly,
                    "isTruncated": isTruncated
                ]
            )
        }
    }

    /// 发送文本选择已更改的通知（文件预览特有）
    /// 自动在主线程发送通知
    /// - Parameter selection: 代码选区信息（nil 表示取消选择）
    @MainActor
    static func postFilePreviewTextSelectionChanged(selection: CodeSelectionRange?) {
        var userInfo: [String: Any] = [:]
        if let selection = selection {
            userInfo["selection"] = selection
        }
        NotificationCenter.default.post(
            name: .filePreviewTextSelectionChanged,
            object: nil,
            userInfo: userInfo.isEmpty ? nil : userInfo
        )
    }
}

// MARK: - View Extensions for File Preview Events

extension View {
    /// 监听文件预览主题已更改的事件
    /// - Parameter action: 事件处理闭包，参数为主题名称
    /// - Returns: 修改后的视图
    func onFilePreviewThemeChanged(perform action: @escaping (CodeEditor.ThemeName) -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .filePreviewThemeDidChange)) { notification in
            guard let userInfo = notification.userInfo,
                  let themeRawValue = userInfo["theme"] as? String,
                  let theme = CodeEditor.availableThemes.first(where: { $0.rawValue == themeRawValue }) else {
                return
            }
            action(theme)
        }
    }

    /// 监听文件内容已保存的事件
    /// - Parameter action: 事件处理闭包，参数为(文件 URL, 是否成功, 错误信息)
    /// - Returns: 修改后的视图
    func onFileContentSaved(perform action: @escaping (URL, Bool, String?) -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .fileContentSaved)) { notification in
            guard let fileURL = notification.object as? URL,
                  let userInfo = notification.userInfo,
                  let success = userInfo["success"] as? Bool else {
                return
            }
            let error = userInfo["error"] as? String
            action(fileURL, success, error)
        }
    }

    /// 监听文件预览模式已更改的事件
    /// - Parameter action: 事件处理闭包，参数为(是否只读, 是否截断)
    /// - Returns: 修改后的视图
    func onFilePreviewModeChanged(perform action: @escaping (Bool, Bool) -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .filePreviewModeChanged)) { notification in
            guard let userInfo = notification.userInfo,
                  let isReadOnly = userInfo["isReadOnly"] as? Bool,
                  let isTruncated = userInfo["isTruncated"] as? Bool else {
                return
            }
            action(isReadOnly, isTruncated)
        }
    }

    /// 监听文本选择已更改的事件（文件预览特有）
    /// - Parameter action: 事件处理闭包，参数为代码选区信息（nil 表示取消选择）
    /// - Returns: 修改后的视图
    func onFilePreviewTextSelectionChanged(perform action: @escaping (CodeSelectionRange?) -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .filePreviewTextSelectionChanged)) { notification in
            guard let userInfo = notification.userInfo else {
                action(nil)
                return
            }

            if let selection = userInfo["selection"] as? CodeSelectionRange {
                action(selection)
            } else if userInfo["selection"] is NSNull {
                action(nil)
            }
        }
    }
}
