import Combine
import Foundation

/// 项目管理能力协议
///
/// 定义宿主需要的项目管理功能，由具体实现（如 ProjectsPlugin / 单用途 App）注入。
///
/// `ObjectWillChangePublisher == ObservableObjectPublisher` 约束与 `MessageSending` 一致，
/// 用于让协议存在类型（`any ProjectProviding`）的 `objectWillChange` 可被订阅，从而支持
/// SwiftUI 跨包响应式观察。
@MainActor
public protocol ProjectProviding: ObservableObject where ObjectWillChangePublisher == ObservableObjectPublisher {
    /// 当前打开的项目
    var currentProject: ProjectInfo? { get }

    /// 当前项目已打开的文件
    var openFileURLs: [URL] { get }

    /// 当前选中的文件
    var currentFileURL: URL? { get }

    /// 所有项目列表
    var projects: [ProjectInfo] { get }

    /// 打开项目
    func openProject(at path: String) async throws

    /// 更新当前文件
    func updateCurrentFile(_ fileURL: URL?)

    /// 更新当前项目已打开的文件
    func updateOpenFiles(_ fileURLs: [URL])

    /// 关闭指定文件（从打开文件列表中移除）
    func closeFile(_ fileURL: URL)

    /// 关闭当前项目
    func closeProject() async

    /// 刷新项目列表
    func refreshProjects() async throws

    /// 同步应用当前维护的完整项目列表。
    ///
    /// 默认实现保持向后兼容；拥有项目持久化能力的实现应覆盖此方法。
    func synchronizeProjects(_ projects: [ProjectInfo])
}

public extension ProjectProviding {
    var openFileURLs: [URL] { [] }

    var currentFileURL: URL? { nil }

    func updateCurrentFile(_ fileURL: URL?) {}

    func updateOpenFiles(_ fileURLs: [URL]) {}

    func closeFile(_ fileURL: URL) {}

    func synchronizeProjects(_ projects: [ProjectInfo]) {}
}
