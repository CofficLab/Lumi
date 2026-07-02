import Foundation
import SuperLogKit
import os

public enum LumiCurrentProjectPathUserInfoKey {
    public static let path = "path"
    public static let reason = "reason"
}

public extension Notification.Name {
    static let lumiCurrentProjectPathDidChange = Notification.Name("lumi.currentProjectPathDidChange")
}

public protocol LumiCurrentProjectPathProviding: Sendable {
    var currentProjectPath: String { get }
}

public protocol LumiCurrentProjectPathStoring: LumiCurrentProjectPathProviding {
    func setCurrentProjectPath(_ path: String, reason: String)
}

/// 项目路径 Store，负责维护当前选中项目路径的状态和通知。
///
/// ProjectsPlugin 在 select/remove 项目时会调用 `setCurrentProjectPath`，
/// 确保通知正常发出，供 WindowProjectVM 等组件监听。
public final class LumiCurrentProjectPathStore: LumiCurrentProjectPathStoring, @unchecked Sendable, SuperLog {
    nonisolated public static let emoji = "📂"
    nonisolated static let verbose: Bool = false

    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "core.project-path")

    private let lock = NSLock()
    private var path = ""

    public init() {}

    public var currentProjectPath: String {
        lock.lock()
        defer { lock.unlock() }
        return path
    }

    public func setCurrentProjectPath(_ newValue: String, reason: String = "") {
        lock.lock()
        let changed = path != newValue
        path = newValue
        lock.unlock()
        guard changed else { return }
        if Self.verbose {
            let reasonSuffix = reason.isEmpty ? "" : "，原因：\(reason)"
            Self.logger.info("\(Self.t)当前项目路径已更改：\(newValue)\(reasonSuffix)")
        }
        NotificationCenter.default.post(
            name: .lumiCurrentProjectPathDidChange,
            object: nil,
            userInfo: [
                LumiCurrentProjectPathUserInfoKey.path: newValue,
                LumiCurrentProjectPathUserInfoKey.reason: reason
            ]
        )
    }
}
