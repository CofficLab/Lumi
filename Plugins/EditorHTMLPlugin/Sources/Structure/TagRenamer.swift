import Foundation

/// HTML 联动重命名
///
/// 当用户修改开标签名时，自动同步修改对应的闭标签。
/// 使用多光标技术，一处修改，处处同步。
@MainActor
public final class TagRenamer {
    /// 查找需要同步修改的标签位置
    ///
    /// - Parameters:
    ///   - lines: 文档所有行的文本
    ///   - line: 当前光标所在行（0-based）
    ///   - character: 当前光标所在列（0-based）
    /// - Returns: 所有需要修改的标签位置 (line, startColumn, length)
    public static func findLinkedTags(lines: [String], line: Int, character: Int) -> [(line: Int, startColumn: Int, length: Int)] {
        var linkedTags: [(line: Int, startColumn: Int, length: Int)] = []

        guard let match = TagMatcher.findTagPair(lines: lines, line: line, character: character) else {
            return linkedTags
        }

        // 如果找到了匹配标签，添加为联动编辑点
        let currentTag = match.current
        if let matching = match.matching, matching.name == currentTag.name {
            // 当前标签
            linkedTags.append((line: currentTag.startLine, startColumn: currentTag.startColumn + (currentTag.isClosing ? 2 : 1), length: currentTag.name.utf16.count))

            // 匹配标签
            linkedTags.append((line: matching.startLine, startColumn: matching.startColumn + (matching.isClosing ? 2 : 1), length: matching.name.utf16.count))
        }

        return linkedTags
    }

    /// 生成重命名编辑操作
    ///
    /// - Parameters:
    ///   - lines: 文档所有行的文本
    ///   - line: 当前光标所在行
    ///   - character: 当前光标所在列
    ///   - newName: 新的标签名
    /// - Returns: 编辑操作数组，每个操作包含位置和新的文本
    public static func generateRenameEdits(
        lines: [String],
        line: Int,
        character: Int,
        newName: String
    ) -> [(line: Int, startColumn: Int, length: Int, newText: String)] {
        var edits: [(line: Int, startColumn: Int, length: Int, newText: String)] = []

        let linkedTags = findLinkedTags(lines: lines, line: line, character: character)

        for tag in linkedTags {
            edits.append((
                line: tag.line,
                startColumn: tag.startColumn,
                length: tag.length,
                newText: newName
            ))
        }

        return edits
    }

    /// 检查当前光标位置是否在可重命名的标签上
    ///
    /// - Parameters:
    ///   - lines: 文档所有行的文本
    ///   - line: 当前光标所在行
    ///   - character: 当前光标所在列
    /// - Returns: 如果是可重命名的标签，返回 true
    public static func isOnRenamableTag(lines: [String], line: Int, character: Int) -> Bool {
        let linkedTags = findLinkedTags(lines: lines, line: line, character: character)
        return linkedTags.count > 1
    }
}
