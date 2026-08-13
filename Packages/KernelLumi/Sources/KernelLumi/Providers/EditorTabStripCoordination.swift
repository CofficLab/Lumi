import Combine
import Foundation

/// 编辑器标签栏(tab strip)与编辑器的协同能力协议
///
/// 定义标签栏 UI 与编辑器之间的双向联动:读取打开的标签列表、订阅变化、
/// 激活/关闭/重排/置顶标签等。由具体编辑器插件实现(当前为 `EditorService`
/// 包的 `EditorContext`),通过 `kernel.resolveService(EditorTabStripCoordination.self)`
/// 取用。
///
/// 设计意图:标签栏只面向 kernel 能力,不依赖具体编辑器服务实现。编辑器能力的
/// 具体实现由其他插件提供。
///
/// `ObjectWillChangePublisher == ObservableObjectPublisher` 约束与
/// `FileTreeEditorCoordination` / `ProjectProviding` 一致,用于让协议存在类型
/// (`any EditorTabStripCoordination`)的 `objectWillChange` 可被订阅。
@MainActor
public protocol EditorTabStripCoordination: ObservableObject where ObjectWillChangePublisher == ObservableObjectPublisher {
    /// 标签列表的变化流(当前标签数组 + 当前激活的 session ID)。
    ///
    /// 标签列表或激活项变化时发出。消费方在 init 时捕获一次 publisher 实例
    /// (避免在 SwiftUI body 里每次重建 publisher 导致死循环),用 `.onReceive` 订阅。
    var tabStripStatePublisher: AnyPublisher<TabStripState, Never> { get }

    /// 当前标签列表快照(只读,同步读取)。
    var currentTabs: [TabDescriptor] { get }

    /// 当前激活的 session ID。
    var currentActiveSessionID: UUID? { get }

    /// 激活并恢复指定 session(切换标签)。
    func activateSession(id: UUID)

    /// 关闭指定 session,返回关闭后应激活的下一个 session ID(若有)。
    @discardableResult
    func closeSession(id: UUID) -> UUID?

    /// 关闭除指定 session 外的所有 session。
    func closeOtherSessions(keeping id: UUID)

    /// 关闭指定 session 左侧的所有 session。
    func closeTabsToLeft(of id: UUID)

    /// 关闭指定 session 右侧的所有 session。
    func closeTabsToRight(of id: UUID)

    /// 切换指定 session 的置顶状态。
    func togglePinned(sessionID: UUID)

    /// 拖拽重排:把 `sessionID` 移动到 `beforeSessionID` 之前(若 nil 则移到末尾)。
    @discardableResult
    func reorderSession(sessionID: UUID, before beforeSessionID: UUID?) -> Bool

    /// 在标签栏打开/激活某文件(用于外部"当前文件变化"通知驱动)。
    func openFile(at url: URL)

    /// 在后台为某文件创建 session(不切换激活的标签),用于从磁盘恢复多标签。
    func openFileSessionInBackground(at url: URL)
}

// MARK: - Value Types

/// 标签栏状态快照(标签列表 + 激活的 session ID)。
public struct TabStripState: Sendable, Equatable {
    public let tabs: [TabDescriptor]
    public let activeSessionID: UUID?

    public init(tabs: [TabDescriptor], activeSessionID: UUID?) {
        self.tabs = tabs
        self.activeSessionID = activeSessionID
    }
}

/// 标签描述符(跨包值类型,与具体编辑器实现解耦)。
///
/// `EditorContext` 将 `EditorService` 的 `EditorTab` 映射为此类型供协议消费方使用,
/// 避免 kernel 及其消费者依赖 `EditorService`/`EditorKernel` 包。
public struct TabDescriptor: Identifiable, Sendable, Equatable {
    public let sessionID: UUID
    public var fileURL: URL?
    public var title: String
    public var isDirty: Bool
    public var isPinned: Bool
    public var isPreview: Bool

    public var id: UUID { sessionID }

    public init(
        sessionID: UUID,
        fileURL: URL?,
        title: String,
        isDirty: Bool,
        isPinned: Bool,
        isPreview: Bool
    ) {
        self.sessionID = sessionID
        self.fileURL = fileURL
        self.title = title
        self.isDirty = isDirty
        self.isPinned = isPinned
        self.isPreview = isPreview
    }
}
