import Foundation

/// HTML 标签位置信息
public struct TagLocation: Equatable, Sendable {
    /// 标签名称
    public let name: String

    /// 标签在文档中的起始行（0-based）
    public let startLine: Int

    /// 标签在文档中的起始列（0-based）
    public let startColumn: Int

    /// 是否为闭标签
    public let isClosing: Bool
}
