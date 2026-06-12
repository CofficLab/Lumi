import Foundation
import LanguageServerProtocol
import os

/// Vue Tree-Sitter 语法注册
///
/// 将 Vue SFC 语法注册到编辑器内核的 Tree-Sitter 基础设施中。
/// 由于 Vue SFC 的特殊性（多语言嵌入），Tree-Sitter 层面需要
/// 使用外部语法（tree-sitter-html + tree-sitter-vue）或降级处理。
///
/// **策略**：
/// - 优先使用 tree-sitter-vue（如果可用）
/// - 降级为 tree-sitter-html（基本的标签高亮）
/// - 最终降级为纯文本（无 Tree-Sitter 支持）
///
/// **注意**：当前 Lumi 内核的 Tree-Sitter 注册机制可能尚不完善，
/// 本模块预留了注册接口，待内核完善后即可接入。
struct VueTreeSitterRegistration: Sendable {
    nonisolated static let emoji = "🌳"
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.vue-editor.treesitter"
    )

    // MARK: - 语言定义

    /// Vue SFC 语言定义
    struct VueLanguageDef: Sendable {
        /// 语言 ID
        let languageId: String = "vue"

        /// 文件扩展名
        let extensions: Set<String> = ["vue"]

        /// 文件名模式
        let filenamePatterns: Set<String> = ["*.vue"]

        /// 显示名称
        let displayName: String = "Vue"

        /// 基础语法语言（用于降级）
        let fallbackLanguageId: String = "html"

        /// 嵌入的子语言
        let embeddedLanguages: Set<String> = [
            "html",    // <template>
            "javascript", "typescript", // <script>
            "css", "scss", "less",      // <style>
            "json",    // <i18n>
        ]
    }

    /// 共享的语言定义实例
    static let languageDefinition = VueLanguageDef()

    // MARK: - SFC 区块识别模式

    /// SFC 区块头的 Tree-Sitter 查询模式
    ///
    /// 用于在 Tree-Sitter AST 中识别 Vue SFC 的结构化区块。
    /// 这些模式可以用于：
    /// - 区块头高亮
    /// - 折叠范围检测
    /// - 区块导航
    struct SFCBlockPatterns {
        /// template 区块开始
        static let templateOpen = #"<template"#
        /// template 区块结束
        static let templateClose = #"</template>"#

        /// script 区块开始（包括 <script setup>）
        static let scriptOpen = #"<script"#
        /// script 区块结束
        static let scriptClose = #"</script>"#

        /// style 区块开始（包括 <style scoped>）
        static let styleOpen = #"<style"#
        /// style 区块结束
        static let styleClose = #"</style>"#
    }

    // MARK: - 折叠范围

    /// SFC 折叠范围类型
    enum FoldingKind: String, Sendable {
        case template
        case script
        case style
        case comment
        case importSection
    }

    /// 从 SFC 区块生成折叠范围
    ///
    /// - Parameter blocks: 解析出的 SFC 区块列表
    /// - Returns: 折叠范围列表
    static func foldingRanges(from blocks: [SFCBlock]) -> [FoldingRange] {
        blocks.map { block in
            FoldingRange(
                startLine: block.startLine,
                startCharacter: nil,
                endLine: block.endLine,
                endCharacter: nil,
                kind: foldingKind(for: block.type)
            )
        }
    }

    /// 获取区块类型对应的折叠范围类型
    private static func foldingKind(for blockType: SFCBlockType) -> FoldingRangeKind? {
        switch blockType {
        case .template: return .region
        case .script: return .region
        case .style: return .region
        }
    }

    // MARK: - 区块切换位置

    /// 区块导航位置信息
    struct BlockNavigationTarget: Sendable {
        /// 区块类型
        let blockType: SFCBlockType

        /// 内容起始行（跳过开标签）
        let contentStartLine: Int

        /// 区块结束行
        let endLine: Int

        /// 是否存在该区块
        let exists: Bool
    }

    /// 为每个区块类型计算导航位置
    ///
    /// - Parameter blocks: 解析出的 SFC 区块列表
    /// - Returns: 各区块的导航位置
    static func navigationTargets(from blocks: [SFCBlock]) -> [SFCBlockType: BlockNavigationTarget] {
        var targets: [SFCBlockType: BlockNavigationTarget] = [:]

        for blockType in SFCBlockType.allCases {
            if let block = SFCBlock.find(type: blockType, in: blocks) {
                targets[blockType] = BlockNavigationTarget(
                    blockType: blockType,
                    contentStartLine: block.startLine + 1,
                    endLine: block.endLine,
                    exists: true
                )
            } else {
                targets[blockType] = BlockNavigationTarget(
                    blockType: blockType,
                    contentStartLine: 0,
                    endLine: 0,
                    exists: false
                )
            }
        }

        return targets
    }

    // MARK: - 语法注入点

    /// Vue 模板中的特殊注入点（需要高亮的位置）
    ///
    /// 这些位置需要从 HTML 模式切换到其他语言模式：
    /// - `{{ }}` 内部 → JavaScript/TypeScript
    /// - `v-bind="..."` 或 `:attr="..."` 内部 → JavaScript/TypeScript
    /// - `@click="..."` 内部 → JavaScript/TypeScript
    /// - `<style>` 内容 → CSS/SCSS/Less
    struct InjectionPoint {
        enum Kind: Sendable {
            case interpolation   // {{ ... }}
            case directive       // v-bind, v-on, v-for 等
            case styleBlock      // <style> 内容
            case scriptBlock     // <script> 内容
        }

        let kind: Kind
        let startLine: Int
        let startChar: Int
        let endLine: Int
        let endChar: Int
    }

    /// 检测模板中的注入点（{{ }} 表达式）
    ///
    /// - Parameter content: 文件内容
    /// - Returns: 注入点列表
    static func detectInjectionPoints(in content: String) -> [InjectionPoint] {
        var points: [InjectionPoint] = []
        let lines = content.components(separatedBy: "\n")

        for (lineIndex, line) in lines.enumerated() {
            // 检测 {{ }} 插值表达式
            var searchStart = line.startIndex
            while let openRange = line.range(of: "{{", range: searchStart..<line.endIndex) {
                guard let closeRange = line.range(of: "}}", range: openRange.upperBound..<line.endIndex) else {
                    break
                }

                points.append(InjectionPoint(
                    kind: .interpolation,
                    startLine: lineIndex,
                    startChar: line.distance(from: line.startIndex, to: openRange.lowerBound),
                    endLine: lineIndex,
                    endChar: line.distance(from: line.startIndex, to: closeRange.upperBound)
                ))

                searchStart = closeRange.upperBound
            }
        }

        return points
    }

    // MARK: - 注册信息

    /// Tree-Sitter 注册所需的语言信息
    ///
    /// 供编辑器内核的 `EditorLanguageContributor` 协议使用。
    static var registrationInfo: [String: Any] {
        [
            "languageId": "vue",
            "extensions": ["vue"],
            "displayName": "Vue",
            "fallbackLanguageId": "html",
            "embeddedLanguages": ["html", "javascript", "typescript", "css", "scss", "less", "json"],
        ]
    }
}
