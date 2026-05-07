import Foundation

/// HTML 标签匹配器
///
/// 基于栈扫描算法，定位匹配的开/闭标签。
/// 用于标签高亮和联动重命名。
enum TagMatcher {
    /// 在指定行附近查找匹配的标签位置
    ///
    /// - Parameters:
    ///   - lines: 文档所有行的文本
    ///   - line: 当前光标所在行（0-based）
    ///   - character: 当前光标所在列（0-based）
    /// - Returns: 匹配标签的位置，如果未找到则返回 nil
    static func findMatchingTag(lines: [String], line: Int, character: Int) -> TagLocation? {
        // 1. 在当前位置找到光标所在的标签名
        guard let currentTag = extractTagName(at: line, character: character, lines: lines) else {
            return nil
        }

        // 2. 判断是开标签还是闭标签
        if currentTag.isClosing {
            // 闭标签 → 向前搜索对应的开标签
            return findOpeningTag(for: currentTag.name, from: line, lines: lines)
        } else {
            // 开标签 → 向后搜索对应的闭标签
            return findClosingTag(for: currentTag.name, from: line, lines: lines)
        }
    }

    // MARK: - 私有方法

    /// 提取光标位置处的标签名
    private static func extractTagName(at line: Int, character: Int, lines: [String]) -> TagLocation? {
        guard line >= 0, line < lines.count else { return nil }
        let text = lines[line]

        // 将 Int 索引转为 String.Index
        guard charIndex(at: character, in: text) != nil else { return nil }

        // 查找光标所在的 <...> 区间
        var tagStartIdx: String.Index?
        var idx = charIndex(at: character, in: text) ?? text.startIndex

        while idx > text.startIndex {
            if text[idx] == "<" {
                tagStartIdx = idx
                break
            }
            idx = text.index(before: idx)
        }
        // 检查起始位置
        if tagStartIdx == nil, text[text.startIndex] == "<" {
            tagStartIdx = text.startIndex
        }

        guard let tagStart = tagStartIdx else { return nil }

        // 查找 >
        var tagEnd = text.index(after: tagStart)
        while tagEnd < text.endIndex, text[tagEnd] != ">" {
            tagEnd = text.index(after: tagEnd)
        }

        let tagContent = String(text[tagStart..<min(tagEnd, text.endIndex)])
        let isClosing = tagContent.hasPrefix("</")

        // 提取标签名
        let nameStartIdx = tagContent.index(tagContent.startIndex, offsetBy: isClosing ? 2 : 1)
        var nameEndIdx = nameStartIdx
        while nameEndIdx < tagContent.endIndex {
            let c = tagContent[nameEndIdx]
            if c.isWhitespace || c == ">" || c == "/" { break }
            nameEndIdx = tagContent.index(after: nameEndIdx)
        }

        let name = String(tagContent[nameStartIdx..<nameEndIdx]).lowercased()
        guard !name.isEmpty else { return nil }

        let column = text.distance(from: text.startIndex, to: tagStart)
        return TagLocation(name: name, startLine: line, startColumn: column, isClosing: isClosing)
    }

    /// 向后搜索闭标签
    private static func findClosingTag(for name: String, from startLine: Int, lines: [String]) -> TagLocation? {
        var depth = 1

        for lineIndex in startLine..<lines.count {
            let tags = parseTags(in: lines[lineIndex], lineIndex: lineIndex)

            for tag in tags {
                if tag.name == name {
                    if tag.isClosing {
                        depth -= 1
                        if depth == 0 { return tag }
                    } else if !HTMLKnowledgeBase.voidElements.contains(tag.name) {
                        depth += 1
                    }
                }
            }
        }

        return nil
    }

    /// 向前搜索开标签
    private static func findOpeningTag(for name: String, from startLine: Int, lines: [String]) -> TagLocation? {
        var depth = 1

        for lineIndex in stride(from: startLine, through: 0, by: -1) {
            let tags = parseTags(in: lines[lineIndex], lineIndex: lineIndex)

            for tag in tags.reversed() {
                if tag.name == name {
                    if !tag.isClosing {
                        depth -= 1
                        if depth == 0 { return tag }
                    } else {
                        depth += 1
                    }
                }
            }
        }

        return nil
    }

    /// 解析一行文本中的所有标签
    private static func parseTags(in text: String, lineIndex: Int) -> [TagLocation] {
        var result: [TagLocation] = []
        var i = text.startIndex

        while i < text.endIndex {
            // 查找 <
            guard let openBracket = text[i...].firstIndex(of: "<") else { break }
            i = openBracket

            // 查找 >
            guard let closeBracket = text[i...].firstIndex(of: ">") else { break }

            let tagContent = String(text[i...closeBracket])
            let isClosing = tagContent.hasPrefix("</")

            // 提取标签名
            let nameStart = tagContent.index(tagContent.startIndex, offsetBy: isClosing ? 2 : 1)
            var nameEnd = nameStart
            while nameEnd < tagContent.endIndex {
                let c = tagContent[nameEnd]
                if c.isWhitespace || c == ">" || c == "/" { break }
                nameEnd = tagContent.index(after: nameEnd)
            }

            let name = String(tagContent[nameStart..<nameEnd]).lowercased()
            if !name.isEmpty {
                let column = text.distance(from: text.startIndex, to: openBracket)
                result.append(TagLocation(name: name, startLine: lineIndex, startColumn: column, isClosing: isClosing))
            }

            i = text.index(after: closeBracket)
        }

        return result
    }

    /// 将 Int 列号转为 String.Index
    private static func charIndex(at column: Int, in text: String) -> String.Index? {
        guard column >= 0 else { return nil }
        var idx = text.startIndex
        var count = 0
        while count < column, idx < text.endIndex {
            idx = text.index(after: idx)
            count += 1
        }
        return idx
    }
}
