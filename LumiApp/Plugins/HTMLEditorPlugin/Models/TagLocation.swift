import Foundation

/// HTML 标签位置信息
struct TagLocation: Equatable, Sendable {
    /// 标签名称
    let name: String

    /// 标签在文档中的起始行（0-based）
    let startLine: Int

    /// 标签在文档中的起始列（0-based）
    let startColumn: Int

    /// 是否为闭标签
    let isClosing: Bool
}
