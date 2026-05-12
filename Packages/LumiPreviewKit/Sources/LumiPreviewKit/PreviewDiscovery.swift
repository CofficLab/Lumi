import Foundation

/// 预览发现结果：从源码中检测到的单个 #Preview 宏信息。
public struct PreviewDiscovery: Identifiable, Codable, Sendable {
    /// 稳定标识符，用于在 UI 和宿主请求之间关联同一个预览。
    public let id: String

    /// 预览标题；来自 `#Preview("Title")`，未提供时由扫描器生成默认标题。
    public let title: String

    /// 声明该预览的 Swift 源文件路径。
    public let sourceFileURL: URL

    /// `#Preview` 起始行号，基于 1。
    public let lineNumber: Int

    /// `#Preview` 闭包结束行号，基于 1。
    public let endLineNumber: Int

    /// 从预览闭包第一条表达式推断出的主视图类型名。
    public let primaryTypeName: String?

    /// `#Preview` 闭包内的源码文本。
    public let bodySource: String?

    /// 发现该预览时的完整源码文本。
    ///
    /// 编辑器内实时预览会传入未保存的 buffer 内容，构建预览 entry 时优先使用它，
    /// 避免刷新时读到磁盘上的旧文件。
    public let sourceText: String?

    /// 创建一个预览发现结果。
    ///
    /// - Parameters:
    ///   - id: 稳定标识符。
    ///   - title: 预览标题。
    ///   - sourceFileURL: 源文件路径。
    ///   - lineNumber: 起始行号，基于 1。
    ///   - endLineNumber: 结束行号，基于 1。
    ///   - primaryTypeName: 主视图类型名。
    ///   - bodySource: 预览闭包源码。
    public init(
        id: String,
        title: String,
        sourceFileURL: URL,
        lineNumber: Int,
        endLineNumber: Int,
        primaryTypeName: String? = nil,
        bodySource: String? = nil,
        sourceText: String? = nil
    ) {
        self.id = id
        self.title = title
        self.sourceFileURL = sourceFileURL
        self.lineNumber = lineNumber
        self.endLineNumber = endLineNumber
        self.primaryTypeName = primaryTypeName
        self.bodySource = bodySource
        self.sourceText = sourceText
    }
}
