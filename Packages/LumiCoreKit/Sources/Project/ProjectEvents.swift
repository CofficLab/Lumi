import Foundation
import SwiftUI

// MARK: - Notification Names

extension Notification.Name {
    /// 项目列表已更新（添加或删除项目）
    /// object: nil
    /// userInfo: nil
    public static let projectListDidChange = Notification.Name("ProjectListDidChange")
    
    /// 当前选中的项目已变更
    /// object: nil
    /// userInfo: ["project": LumiProjectEntry]
    public static let currentProjectDidChange = Notification.Name("CurrentProjectDidChange")
    
    /// 当前项目路径已变更
    /// object: nil
    /// userInfo: ["path": String]
    public static let currentProjectPathDidChange = Notification.Name("CurrentProjectPathDidChange")

    /// LLM providers 已注册完成
    /// object: nil
    /// userInfo: nil
    public static let lumiLLMProvidersDidChange = Notification.Name("LumiLLMProvidersDidChange")
}

// MARK: - NotificationCenter Extensions

extension NotificationCenter {
    /// 发送项目列表已更新的通知
    public static func postProjectListDidChange() {
        NotificationCenter.default.post(
            name: .projectListDidChange,
            object: nil,
            userInfo: nil
        )
    }
    
    /// 发送当前项目已变更的通知
    public static func postCurrentProjectDidChange(project: LumiProjectEntry) {
        NotificationCenter.default.post(
            name: .currentProjectDidChange,
            object: nil,
            userInfo: ["project": project]
        )
    }
    
    /// 发送当前项目路径已变更的通知
    public static func postCurrentProjectPathDidChange(path: String) {
        NotificationCenter.default.post(
            name: .currentProjectPathDidChange,
            object: nil,
            userInfo: ["path": path]
        )
    }
}

// MARK: - SwiftUI View Helpers

public extension View {
    /// 监听当前项目变更通知。
    ///
    /// 目前底层事件只携带新项目；若需要前后对比，建议上游在发送通知前缓存 `LumiProjectState.currentProject`。
    func onCurrentProjectDidChange(perform action: @escaping (LumiProjectEntry) -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .currentProjectDidChange)) { notification in
            guard let project = notification.userInfo?["project"] as? LumiProjectEntry else { return }
            action(project)
        }
    }
}
