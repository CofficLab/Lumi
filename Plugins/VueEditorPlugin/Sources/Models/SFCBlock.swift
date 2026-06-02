import Foundation

/// SFC 区块类型
///
/// 对应 Vue 单文件组件中的三个顶级区块。
enum SFCBlockType: String, Sendable, CaseIterable {
    case template
    case script
    case style

    /// 区块标签名
    var tagName: String { rawValue }

    /// 区块显示名称
    var displayName: String {
        switch self {
        case .template: return "Template"
        case .script: return "Script"
        case .style: return "Style"
        }
    }

    /// SF Symbol 图标
    var systemImage: String {
        switch self {
        case .template: return "anglebrackets.left"
        case .script: return "curlybraces"
        case .style: return "paintbrush"
        }
    }
}

/// SFC 区块模型
///
/// 表示 `.vue` 文件中解析出的一个区块（如 `<template>`、`<script setup>`、`<style scoped>`），
/// 包含区块类型、属性、内容和在文件中的行范围。
struct SFCBlock: Sendable {
    /// 区块类型
    let type: SFCBlockType

    /// 开标签属性（如 `setup`、`scoped`、`lang="ts"`）
    let attributes: [String: String]

    /// 区块内容
    let content: String

    /// 区块在文件中的起始行（0-based）
    let startLine: Int

    /// 区块在文件中的结束行（0-based）
    let endLine: Int

    /// 是否为 `<script setup>`
    var isSetup: Bool { attributes["setup"] != nil }

    /// 是否为 `<style scoped>`
    var isScoped: Bool { attributes["scoped"] != nil }

    /// 是否为 `<style module>`
    var isModule: Bool { attributes["module"] != nil }

    /// 语言（如 `ts`、`scss`、`less`）
    var lang: String? { attributes["lang"] }

    // MARK: - 解析

    /// 从 `.vue` 文件内容中解析所有 SFC 区块
    ///
    /// - Parameter text: `.vue` 文件的完整文本
    /// - Returns: 解析出的区块列表，按出现顺序排列
    static func parse(from text: String) -> [SFCBlock] {
        var blocks: [SFCBlock] = []
        let lines = text.components(separatedBy: "\n")

        var currentType: SFCBlockType?
        var currentAttributes: [String: String] = [:]
        var contentLines: [String] = []
        var startLine = 0
        var inBlock = false

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if !inBlock {
                // 检测开标签
                for blockType in SFCBlockType.allCases {
                    if trimmed.hasPrefix("<\(blockType.tagName)") {
                        currentType = blockType
                        currentAttributes = parseAttributes(from: trimmed, tagName: blockType.tagName)
                        startLine = index
                        contentLines = []
                        inBlock = true

                        // 单行标签内容（如 `<script setup>const x = 1</script>`）
                        if let closeRange = trimmed.range(of: "</\(blockType.tagName)>") {
                            let contentStart = trimmed.index(after: trimmed.firstIndex(of: ">") ?? trimmed.startIndex)
                            let singleLineContent = String(trimmed[contentStart..<closeRange.lowerBound])
                            blocks.append(SFCBlock(
                                type: blockType,
                                attributes: currentAttributes,
                                content: singleLineContent,
                                startLine: index,
                                endLine: index
                            ))
                            inBlock = false
                            currentType = nil
                        }
                        break
                    }
                }
            } else if let type = currentType {
                // 检测闭标签
                if trimmed.contains("</\(type.tagName)>") {
                    let content = contentLines.joined(separator: "\n")
                    blocks.append(SFCBlock(
                        type: type,
                        attributes: currentAttributes,
                        content: content,
                        startLine: startLine,
                        endLine: index
                    ))
                    inBlock = false
                    currentType = nil
                } else {
                    contentLines.append(line)
                }
            }
        }

        return blocks
    }

    // MARK: - 查找

    /// 根据行号查找所在区块
    static func blockAt(line: Int, in blocks: [SFCBlock]) -> SFCBlock? {
        blocks.first { line >= $0.startLine && line <= $0.endLine }
    }

    /// 查找指定类型的区块
    static func find(type: SFCBlockType, in blocks: [SFCBlock]) -> SFCBlock? {
        blocks.first { $0.type == type }
    }

    // MARK: - 私有方法

    /// 解析开标签中的属性
    private static func parseAttributes(from line: String, tagName: String) -> [String: String] {
        var attrs: [String: String] = [:]
        let tagPrefix = "<\(tagName)"

        guard let tagStart = line.range(of: tagPrefix) else { return attrs }
        let afterTag = line[tagStart.upperBound...]

        // 简易属性解析：匹配 attr="value" 或 attr 或 attr='value'
        let pattern = #"(\w[\w-]*)(?:=["']([^"']*)["'])?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return attrs }

        let nsRange = NSRange(afterTag.startIndex..., in: afterTag)
        for match in regex.matches(in: String(afterTag), range: nsRange) {
            if let nameRange = Range(match.range(at: 1), in: afterTag) {
                let name = String(afterTag[nameRange])
                if name == ">" || name == "/" { continue }

                if let valueRange = Range(match.range(at: 2), in: afterTag) {
                    attrs[name] = String(afterTag[valueRange])
                } else {
                    attrs[name] = ""
                }
            }
        }

        return attrs
    }
}
