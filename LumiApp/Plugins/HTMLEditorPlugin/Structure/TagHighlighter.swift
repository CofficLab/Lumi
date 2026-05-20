import Foundation
import AppKit

/// HTML 匹配标签高亮渲染
///
/// 当光标在标签名上时，高亮对应的开标签和闭标签。
@MainActor
final class TagHighlighter: SuperEditorDecorationContributor {
    let id = "html.tag-highlighter"

    func provideGutterDecorations(
        context: EditorGutterDecorationContext,
        state: EditorState
    ) -> [EditorGutterDecorationSuggestion] {
        []
    }

    /// 高亮颜色配置
    static let highlightColor = NSColor.systemBlue.withAlphaComponent(0.15)
    static let borderColor = NSColor.systemBlue.withAlphaComponent(0.4)

    /// 获取需要高亮的区域
    ///
    /// - Parameters:
    ///   - lines: 文档所有行的文本
    ///   - line: 当前光标所在行（0-based）
    ///   - character: 当前光标所在列（0-based）
    /// - Returns: 需要高亮的区域数组 [(line, startColumn, length)]
    static func highlightRegions(lines: [String], line: Int, character: Int) -> [(line: Int, startColumn: Int, length: Int)] {
        var regions: [(line: Int, startColumn: Int, length: Int)] = []

        guard let match = TagMatcher.findTagPair(lines: lines, line: line, character: character) else {
            return regions
        }

        // 高亮当前标签
        let currentTag = match.current
        regions.append((line: currentTag.startLine, startColumn: currentTag.startColumn, length: currentTag.name.utf16.count + (currentTag.isClosing ? 2 : 1)))

        // 高亮匹配标签
        if let matching = match.matching {
            let tagLength = matching.name.utf16.count + (matching.isClosing ? 2 : 1)
            regions.append((line: matching.startLine, startColumn: matching.startColumn, length: tagLength))
        }

        return regions
    }
}
