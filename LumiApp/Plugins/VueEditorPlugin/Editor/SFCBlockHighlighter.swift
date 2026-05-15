import Foundation
import SwiftUI
import os

/// SFC 区块高亮器
///
/// 提供 Vue SFC 文件中三大区块（template / script / style）的视觉增强：
/// - 区块头标签高亮（与普通 HTML 标签区分）
/// - 区块独立折叠
/// - 区块分隔线渲染
/// - 当前光标所在区块指示
///
/// 本模块作为 `SuperEditorDecorationContributor` 提供，
/// 在编辑器中渲染区块级别的装饰。
@MainActor
final class SFCBlockHighlighter {
    nonisolated static let emoji = "🎨"
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.vue-editor.block-highlighter"
    )

    // MARK: - 区块样式配置

    /// 区块视觉样式
    struct BlockStyle: Sendable {
        /// 区块类型
        let blockType: SFCBlockType

        /// 标签栏背景色（light / dark）
        let backgroundColor: (light: String, dark: String)

        /// 标签栏文字色（light / dark）
        let foregroundColor: (light: String, dark: String)

        /// 左侧边线颜色（light / dark）
        let accentColor: (light: String, dark: String)

        /// SF Symbol 图标
        let icon: String

        /// 标签显示文本
        let label: String
    }

    /// 预设的区块样式
    nonisolated(unsafe) static let blockStyles: [SFCBlockType: BlockStyle] = [
        .template: BlockStyle(
            blockType: .template,
            backgroundColor: (light: "#E8F5E9", dark: "#1B3A1D"),
            foregroundColor: (light: "#2E7D32", dark: "#81C784"),
            accentColor: (light: "#4CAF50", dark: "#66BB6A"),
            icon: "anglebrackets.left",
            label: "template"
        ),
        .script: BlockStyle(
            blockType: .script,
            backgroundColor: (light: "#E3F2FD", dark: "#0D2744"),
            foregroundColor: (light: "#1565C0", dark: "#64B5F6"),
            accentColor: (light: "#2196F3", dark: "#42A5F5"),
            icon: "curlybraces",
            label: "script"
        ),
        .style: BlockStyle(
            blockType: .style,
            backgroundColor: (light: "#F3E5F5", dark: "#2A1540"),
            foregroundColor: (light: "#7B1FA2", dark: "#CE93D8"),
            accentColor: (light: "#9C27B0", dark: "#AB47BC"),
            icon: "paintbrush",
            label: "style"
        ),
    ]

    // MARK: - 区块装饰信息

    /// 区块装饰（用于编辑器渲染）
    struct BlockDecoration: Sendable {
        /// 区块类型
        let blockType: SFCBlockType

        /// 起始行（0-based）
        let startLine: Int

        /// 结束行（0-based）
        let endLine: Int

        /// 开标签文本（如 `<script setup lang="ts">`）
        let openTag: String

        /// 闭标签文本（如 `</script>`）
        let closeTag: String

        /// 属性摘要（如 "setup, lang=ts"）
        let attributesSummary: String

        /// 内容行数
        let contentLineCount: Int

        /// 是否为当前活跃区块（光标所在）
        var isActive: Bool = false

        /// 区块样式
        var style: BlockStyle? {
            SFCBlockHighlighter.blockStyles[blockType]
        }
    }

    // MARK: - 解析装饰

    /// 从文件内容解析出所有区块装饰
    ///
    /// - Parameter content: .vue 文件完整内容
    /// - Returns: 区块装饰列表
    static func parseDecorations(from content: String) -> [BlockDecoration] {
        let blocks = SFCBlock.parse(from: content)
        let lines = content.components(separatedBy: "\n")

        return blocks.map { block in
            // 提取开标签行
            let openTagLine: String
            if block.startLine < lines.count {
                openTagLine = lines[block.startLine].trimmingCharacters(in: .whitespaces)
            } else {
                openTagLine = "<\(block.type.tagName)>"
            }

            // 提取闭标签行
            let closeTagLine: String
            if block.endLine < lines.count {
                closeTagLine = lines[block.endLine].trimmingCharacters(in: .whitespaces)
            } else {
                closeTagLine = "</\(block.type.tagName)>"
            }

            // 构建属性摘要
            let attrs = block.attributes
            var attrParts: [String] = []
            if block.isSetup { attrParts.append("setup") }
            if block.isScoped { attrParts.append("scoped") }
            if block.isModule { attrParts.append("module") }
            if let lang = block.lang { attrParts.append("lang=\(lang)") }
            let attributesSummary = attrParts.isEmpty ? "" : attrParts.joined(separator: ", ")

            return BlockDecoration(
                blockType: block.type,
                startLine: block.startLine,
                endLine: block.endLine,
                openTag: openTagLine,
                closeTag: closeTagLine,
                attributesSummary: attributesSummary,
                contentLineCount: block.content.components(separatedBy: "\n").count
            )
        }
    }

    /// 判断指定行所在的活跃区块
    ///
    /// - Parameters:
    ///   - line: 光标所在行（0-based）
    ///   - decorations: 区块装饰列表
    /// - Returns: 活跃区块类型
    static func activeBlock(at line: Int, decorations: [BlockDecoration]) -> SFCBlockType? {
        decorations.first { line >= $0.startLine && line <= $0.endLine }?.blockType
    }

    // MARK: - 区块分隔标记

    /// 区块之间的分隔标记（用于面包屑导航）
    struct BlockSeparator: Sendable {
        /// 分隔行号
        let line: Int

        /// 上方区块
        let aboveBlock: SFCBlockType?

        /// 下方区块
        let belowBlock: SFCBlockType?
    }

    /// 计算区块之间的分隔位置
    static func separators(from decorations: [BlockDecoration]) -> [BlockSeparator] {
        guard decorations.count > 1 else { return [] }

        var result: [BlockSeparator] = []
        let sorted = decorations.sorted { $0.startLine < $1.startLine }

        for i in 0..<(sorted.count - 1) {
            let current = sorted[i]
            let next = sorted[i + 1]

            // 区块之间可能有空行
            let separatorLine = current.endLine + 1
            if separatorLine < next.startLine {
                result.append(BlockSeparator(
                    line: separatorLine,
                    aboveBlock: current.blockType,
                    belowBlock: next.blockType
                ))
            }
        }

        return result
    }

    // MARK: - 区块摘要（用于面包屑）

    /// 区块面包屑信息
    struct BlockBreadcrumb: Sendable {
        /// 区块类型
        let blockType: SFCBlockType

        /// 显示标签（如 "script setup · ts"）
        let displayLabel: String

        /// 行范围
        let lineRange: Range<Int>

        /// 是否为当前活跃区块
        let isActive: Bool
    }

    /// 生成面包屑导航信息
    ///
    /// - Parameters:
    ///   - decorations: 区块装饰列表
    ///   - cursorLine: 当前光标行（0-based）
    /// - Returns: 面包屑列表
    static func breadcrumbs(
        decorations: [BlockDecoration],
        cursorLine: Int
    ) -> [BlockBreadcrumb] {
        decorations.sorted { $0.startLine < $1.startLine }.map { dec in
            var label = dec.blockType.tagName
            if !dec.attributesSummary.isEmpty {
                label += " \(dec.attributesSummary)"
            }

            return BlockBreadcrumb(
                blockType: dec.blockType,
                displayLabel: label,
                lineRange: dec.startLine..<(dec.endLine + 1),
                isActive: cursorLine >= dec.startLine && cursorLine <= dec.endLine
            )
        }
    }
}
