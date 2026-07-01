import Foundation

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
