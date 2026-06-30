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
    ///
    /// 与 `add(path:select:)` 的区别：不校验目录是否存在，用于"切换到某个对话绑定的项目"
    /// 这类场景——即使目录已被移走/删除，也要让当前项目指向它，由真正使用该路径的消费者在使用时报错。
    /// 传空串表示切到"无项目"态。
    func setCurrentProjectPath(_ path: String, reason: String)
}
