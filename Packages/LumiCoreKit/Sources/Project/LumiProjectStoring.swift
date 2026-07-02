import Foundation

// MARK: - Protocol

/// 项目列表存储协议，供插件通过 `LumiPluginDependencies.resolve(LumiProjectStoring.self)` 获取。
@MainActor
public protocol LumiProjectStoring: AnyObject {
    var projects: [LumiProjectEntry] { get }
    var currentProject: LumiProjectEntry? { get }

    func select(_ project: LumiProjectEntry)
    @discardableResult
    func add(path: String, select shouldSelect: Bool) throws -> LumiProjectEntry
    func remove(_ project: LumiProjectEntry)

    /// 无条件把"当前项目"切到指定路径。
    func setCurrentProjectPath(_ path: String, reason: String)
}
