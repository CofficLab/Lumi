import Foundation

public enum LumiCurrentProjectPathUserInfoKey {
    public static let path = "path"
}

public extension Notification.Name {
    static let lumiCurrentProjectPathDidChange = Notification.Name("lumi.currentProjectPathDidChange")
}

public protocol LumiCurrentProjectPathProviding: Sendable {
    var currentProjectPath: String { get }
}

public protocol LumiCurrentProjectPathStoring: LumiCurrentProjectPathProviding {
    func setCurrentProjectPath(_ path: String)
}

/// 项目路径 Store，负责维护当前选中项目路径的状态和通知。
///
/// ProjectsPlugin 在 select/remove 项目时会调用 `setCurrentProjectPath`，
/// 确保通知正常发出，供 WindowProjectVM 等组件监听。
public final class LumiCurrentProjectPathStore: LumiCurrentProjectPathStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var path = ""

    public init() {}

    public var currentProjectPath: String {
        lock.lock()
        defer { lock.unlock() }
        return path
    }

    public func setCurrentProjectPath(_ newValue: String) {
        lock.lock()
        let changed = path != newValue
        path = newValue
        lock.unlock()
        guard changed else { return }
        NotificationCenter.default.post(
            name: .lumiCurrentProjectPathDidChange,
            object: nil,
            userInfo: [LumiCurrentProjectPathUserInfoKey.path: newValue]
        )
    }
}
