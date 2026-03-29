import Foundation

/// 代码选区范围信息
/// 描述用户在文件中选中的区域，不包含具体内容，仅包含位置信息。
public struct CodeSelectionRange: Equatable {
    /// 文件路径（相对于项目根目录）
    public let filePath: String

    /// 选区起始行号（从 1 开始计数）
    public let startLine: Int

    /// 选区起始列号（从 1 开始计数）
    public let startColumn: Int

    /// 选区结束行号（从 1 开始计数）
    public let endLine: Int

    /// 选区结束列号（从 1 开始计数）
    public let endColumn: Int

    public init(
        filePath: String,
        startLine: Int,
        startColumn: Int,
        endLine: Int,
        endColumn: Int
    ) {
        self.filePath = filePath
        self.startLine = startLine
        self.startColumn = startColumn
        self.endLine = endLine
        self.endColumn = endColumn
    }

    /// 是否为单行选区
    public var isSingleLine: Bool {
        startLine == endLine
    }

    /// 选区跨越的行数
    public var lineCount: Int {
        endLine - startLine + 1
    }

    /// 生成人类可读的描述，如 "main.swift:10:1-15:20"
    public var description: String {
        if isSingleLine {
            return "\(filePath):\(startLine):\(startColumn)-\(endColumn)"
        }
        return "\(filePath):\(startLine):\(startColumn)-\(endLine):\(endColumn)"
    }
}
