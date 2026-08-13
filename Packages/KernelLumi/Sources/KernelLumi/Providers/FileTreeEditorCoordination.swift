import Combine
import Foundation

/// 文件树与编辑器的协同能力协议
///
/// 定义文件树(等 UI 组件)与编辑器之间双向联动所需的协同能力,由具体编辑器插件
/// 实现(当前为 `EditorService` 包的 `EditorContext`)。
///
/// 设计意图:文件树只面向 kernel 能力,不依赖具体编辑器服务实现。文件树通过
/// `kernel.resolveService(FileTreeEditorCoordination.self)` 取得协同器,
/// 编辑器能力的具体实现由其他插件提供。
///
/// `ObjectWillChangePublisher == ObservableObjectPublisher` 约束与 `ProjectProviding`
/// 一致,用于让协议存在类型(`any FileTreeEditorCoordination`)的 `objectWillChange`
/// 可被订阅,从而支持跨包响应式观察。
@MainActor
public protocol FileTreeEditorCoordination: ObservableObject where ObjectWillChangePublisher == ObservableObjectPublisher {
    /// 文件树高亮 URL 的变化流。
    ///
    /// 编辑器当前文件变化时,协同器通过此 publisher 发出新的高亮 URL(或 nil 表示清除),
    /// 文件树订阅后定位并闪烁高亮对应文件。
    var fileTreeHighlightPublisher: AnyPublisher<URL?, Never> { get }

    /// 打开文件(在编辑器中激活对应 session)。
    func openFile(at url: URL)

    /// 关闭匹配给定 URL 的编辑器 session(用于文件树删除后清理残留 tab)。
    /// - Parameter urls: 已删除的文件/目录 URL 列表。
    func closeSessions(forURLs urls: [URL])

    /// 关闭旧路径的编辑器 tab 并打开新路径(用于文件树重命名后迁移 tab)。
    func replaceSessionURL(from oldURL: URL, to newURL: URL)

    /// 将文件加入当前窗口的对话输入区。
    func addToConversation(fileURLs: [URL], windowId: UUID?)

    /// 刷新编辑器的项目上下文(如 LSP 根目录)。
    func refreshProjectContext(for projectPath: String) async

    /// 设置文件树高亮 URL(文件树主动选中时回写,避免与编辑器当前文件循环触发)。
    func setFileTreeHighlightedFileURL(_ url: URL)
}

// MARK: - Sync Selected File Notification

/// "同步选中文件"通知名:外部请求文件树定位并打开某文件时,以此通知触发。
/// `userInfo["path"]` 为文件路径字符串。
///
/// 作为独立全局常量暴露,而非协议 static 成员——协议存在类型无法访问 static。
/// 协同器实现(`EditorContext`)与文件树消费方共用此常量保持一致。
public enum FileTreeEditorNotifications {
    /// "同步选中文件"通知名。
    public static let syncSelectedFile = Notification.Name("EditorContext.syncSelectedFile")
}
