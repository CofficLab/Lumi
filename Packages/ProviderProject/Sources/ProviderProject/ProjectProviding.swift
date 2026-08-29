import Foundation

/// 项目管理能力协议
///
/// 定义宿主需要的项目管理功能，由具体实现（如 ProjectsPlugin / 单用途 App）注入。
/// 状态变化统一通过 `ProjectProvidingEvent` 语义通知发布。
///
@MainActor
public protocol ProjectProviding: AnyObject {
    /// 当前打开的项目
    var currentProject: ProjectInfo? { get }

    /// 当前工作区根目录。
    ///
    /// 默认实现使用当前项目路径；支持多根工作区的实现可以覆盖这个值，
    /// 让检索、终端和其他项目能力共享同一个边界。
    var workspaceRoot: String? { get }

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

    /// 以预览方式查看文件；不会将文件固定到打开文件列表。
    func previewFile(_ fileURL: URL)

    /// 将文件固定到打开文件列表并设为当前文件。
    func pinFile(_ fileURL: URL)

    /// 激活已打开文件，不改变打开文件列表。
    func activateFile(_ fileURL: URL)

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
    /// 拥有项目持久化能力的实现应覆盖此方法以持久化项目列表。
    func synchronizeProjects(_ projects: [ProjectInfo])

    // MARK: - Observation

    /// 注册项目状态观察者。
    ///
    /// 回调在主线程同步执行，且执行时对应的 Provider 状态已经更新。观察者
    /// 不应保存 Provider 的强引用；返回的句柄在释放或显式调用 `cancel()` 后
    /// 自动停止接收通知。
    @discardableResult
    func addObserver(_ callback: @escaping (ProjectProvidingEvent) -> Void) -> any ProjectProvidingObserverHandle
}

public extension ProjectProviding {
    var workspaceRoot: String? {
        guard let path = currentProject?.path.trimmingCharacters(in: .whitespacesAndNewlines),
              !path.isEmpty else {
            return nil
        }
        return path
    }

    /// 默认预览行为：仅切换当前文件。
    func previewFile(_ fileURL: URL) {
        updateCurrentFile(fileURL)
    }

    /// 默认固定行为：追加到打开文件列表后切换当前文件。
    func pinFile(_ fileURL: URL) {
        let normalizedURL = fileURL.standardizedFileURL
        var openFileURLs = openFileURLs.map(\.standardizedFileURL)
        if !openFileURLs.contains(normalizedURL) {
            openFileURLs.append(normalizedURL)
            updateOpenFiles(openFileURLs)
        }
        updateCurrentFile(normalizedURL)
    }

    /// 默认激活行为：仅切换当前文件。
    func activateFile(_ fileURL: URL) {
        updateCurrentFile(fileURL)
    }

    /// 轻量项目 Provider 的兼容默认实现。
    ///
    /// 完整实现应覆盖此方法并发出语义事件；默认 no-op 使已有的测试替身和
    /// 外部注入实现可以逐步接入监听能力。
    @discardableResult
    func addObserver(_ callback: @escaping (ProjectProvidingEvent) -> Void) -> any ProjectProvidingObserverHandle {
        NoopProjectProvidingObserverHandle()
    }
}
