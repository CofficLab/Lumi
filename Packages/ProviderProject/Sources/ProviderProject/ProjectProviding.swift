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
    /// 轻量项目 Provider 的兼容默认实现。
    ///
    /// 完整实现应覆盖此方法并发出语义事件；默认 no-op 使已有的测试替身和
    /// 外部注入实现可以逐步接入监听能力，同时仍可使用 `objectWillChange`。
    @discardableResult
    func addObserver(_ callback: @escaping (ProjectProvidingEvent) -> Void) -> any ProjectProvidingObserverHandle {
        NoopProjectProvidingObserverHandle()
    }
}
