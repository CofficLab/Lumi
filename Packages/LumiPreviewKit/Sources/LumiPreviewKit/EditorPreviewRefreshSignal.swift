import Foundation

/// 编辑器预览刷新信号。
///
/// 用于把“源码文本变化”和“保存成功”这两类会触发预览重扫/刷新的事件
/// 收口成一个可比较、可测试的值。
public struct EditorPreviewRefreshSignal: Equatable, Sendable {
    public let fileURL: URL?
    public let contentRevision: UInt64
    public let saveRevision: UInt64

    public init(
        fileURL: URL?,
        contentRevision: UInt64,
        saveRevision: UInt64
    ) {
        self.fileURL = fileURL?.standardizedFileURL
        self.contentRevision = contentRevision
        self.saveRevision = saveRevision
    }

    public func shouldTriggerRefresh(comparedTo previous: Self?) -> Bool {
        previous != self
    }
}
