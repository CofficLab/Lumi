import Foundation

/// 偏移量映射器
///
/// 负责在 HTML 源文档坐标和内嵌语言虚拟文档坐标之间进行双向转换。
///
/// 核心算法：
/// ```
/// HTML 文件:
///   45: <style>
///   46:   .container { width: 100%; }  <-- 虚拟文档行 1
///   47: </style>
///
/// 编辑器请求 (line: 46, char: 5)
///   -> 偏移计算 -> 发送给 CSS LSP (line: 1, char: 5)
///   CSS LSP 返回补全
///   -> 偏移反算 -> 展示在 (line: 46, char: 5)
/// ```
enum OffsetMapper {
    // MARK: - 坐标转换

    /// 将源文档坐标转换为虚拟文档坐标
    ///
    /// - Parameters:
    ///   - line: 源文档行号（0-based）
    ///   - character: 源文档列号（0-based）
    ///   - region: 内嵌语言区域
    ///   - sourceLines: 源文档所有行
    /// - Returns: 虚拟文档坐标 (line, character)
    static func toVirtual(
        line: Int,
        character: Int,
        region: HTMLEmbeddedRegion,
        sourceLines: [String]
    ) -> (line: Int, character: Int)? {
        guard line >= region.lineOffset else { return nil }

        let virtualLine = line - region.lineOffset
        let virtualContentLines = region.virtualContent.components(separatedBy: .newlines)
        guard virtualLine >= 0, virtualLine < virtualContentLines.count else { return nil }

        // 检查列号是否在虚拟行范围内
        let virtualLineText = virtualContentLines[virtualLine]
        guard character <= virtualLineText.utf16.count else { return nil }

        return (line: virtualLine, character: character)
    }

    /// 将虚拟文档坐标转换为源文档坐标
    ///
    /// - Parameters:
    ///   - virtualLine: 虚拟文档行号
    ///   - virtualCharacter: 虚拟文档列号
    ///   - region: 内嵌语言区域
    /// - Returns: 源文档坐标 (line, character)
    static func toSource(
        virtualLine: Int,
        virtualCharacter: Int,
        region: HTMLEmbeddedRegion
    ) -> (line: Int, character: Int) {
        return (
            line: region.lineOffset + virtualLine,
            character: virtualCharacter
        )
    }

    // MARK: - 偏移量计算

    /// 计算给定位置在源文档中的绝对 UTF-16 偏移量
    static func absoluteOffset(line: Int, character: Int, in sourceLines: [String]) -> Int {
        var offset = 0
        for i in 0..<min(line, sourceLines.count) {
            offset += sourceLines[i].utf16.count + 1 // +1 for newline
        }
        if line < sourceLines.count {
            offset += min(character, sourceLines[line].utf16.count)
        }
        return offset
    }

    /// 从绝对偏移量计算行号和列号
    static func lineAndCharacter(from offset: Int, in sourceLines: [String]) -> (line: Int, character: Int)? {
        var currentOffset = 0
        for (lineIndex, line) in sourceLines.enumerated() {
            let lineLength = line.utf16.count + 1
            if currentOffset + lineLength > offset {
                return (line: lineIndex, character: offset - currentOffset)
            }
            currentOffset += lineLength
        }
        return nil
    }

    /// 检查给定坐标是否在内嵌语言区域内
    static func isInRegion(
        line: Int,
        character: Int,
        region: HTMLEmbeddedRegion,
        sourceLines: [String]
    ) -> Bool {
        let offset = absoluteOffset(line: line, character: character, in: sourceLines)
        return region.contains(offset)
    }
}
