import Foundation
import EditorService
import os

/// CSS Modules 类型生成与补全
///
/// 解析 `<style module>` 和 `*.module.css` 中的类名，
/// 在 Script 中输入 `$style.` 时提供类名补全。
///
/// 工作原理：
/// 1. 解析 SFC 的 `<style module>` 区块，提取所有 CSS 类名
/// 2. 在 `<script setup>` 中检测 `$style.` 前缀并提供补全
/// 3. 提供悬浮提示，展示类名对应的 CSS 规则
struct CSSModulesTypeGenerator: Sendable {
    nonisolated static let emoji = "🎨"
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.vue-editor.css-modules"
    )

    // MARK: - CSS 类名信息

    /// CSS 类名条目
    struct CSSClassEntry: Sendable {
        /// 类名
        let name: String

        /// 关联的 CSS 属性摘要（如 "color: red; font-size: 14px"）
        let properties: [String]

        /// 所在行号
        let lineNumber: Int
    }

    // MARK: - 解析

    /// 从 `<style module>` 内容中提取所有类名
    ///
    /// - Parameter styleContent: style 区块的内容
    /// - Returns: 类名列表
    static func parseClassNames(from styleContent: String) -> [CSSClassEntry] {
        var entries: [CSSClassEntry] = [:] as! [CSSClassEntry]
        let lines = styleContent.components(separatedBy: "\n")

        var currentClasses: [String] = []
        var currentProperties: [String] = []
        var braceDepth = 0
        var startLine = 0
        var inBlock = false

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // 跳过注释
            if trimmed.hasPrefix("/*") || trimmed.hasPrefix("*") || trimmed.hasPrefix("//") {
                continue
            }

            // 检测 CSS 选择器行（以 . 开头的类选择器）
            if !inBlock && (trimmed.hasPrefix(".") || trimmed.contains(" .")) {
                let classNames = extractClassNames(from: trimmed)
                if !classNames.isEmpty {
                    currentClasses = classNames
                    currentProperties = []
                    startLine = index
                    inBlock = trimmed.contains("{")
                    braceDepth = countBraces(in: trimmed)
                    continue
                }
            }

            if inBlock {
                braceDepth += countBraces(in: trimmed)

                // 收集属性
                let propLine = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "{};"))
                if !propLine.isEmpty && propLine.contains(":") {
                    currentProperties.append(propLine.trimmingCharacters(in: CharacterSet(charactersIn: "; ")))
                }

                if braceDepth <= 0 {
                    // 块结束
                    for cls in currentClasses {
                        let entry = CSSClassEntry(
                            name: cls,
                            properties: currentProperties,
                            lineNumber: startLine
                        )
                        // 避免重复
                        if !entries.contains(where: { $0.name == cls }) {
                            entries.append(entry)
                        }
                    }
                    inBlock = false
                    currentClasses = []
                    currentProperties = []
                    braceDepth = 0
                }
            }
        }

        return entries
    }

    /// 从 SFC 区块列表中找到所有 `<style module>` 的类名
    ///
    /// - Parameter blocks: SFC 区块列表
    /// - Returns: 类名列表
    static func parseClassNames(from blocks: [SFCBlock]) -> [CSSClassEntry] {
        blocks
            .filter { $0.type == .style && $0.isModule }
            .flatMap { parseClassNames(from: $0.content) }
    }

    // MARK: - 补全

    /// 生成 $style. 补全建议
    ///
    /// - Parameters:
    ///   - prefix: 当前输入前缀（如 `$style.container` 中的 `container`）
    ///   - classEntries: CSS 类名列表
    /// - Returns: 补全建议
    static func completionSuggestions(
        prefix: String,
        classEntries: [CSSClassEntry]
    ) -> [EditorCompletionSuggestion] {
        let normalized = prefix.lowercased()

        return classEntries
            .filter { normalized.isEmpty || $0.name.lowercased().hasPrefix(normalized) }
            .map { entry in
                let detail: String
                if entry.properties.count <= 3 {
                    detail = entry.properties.joined(separator: "; ")
                } else {
                    detail = entry.properties.prefix(3).joined(separator: "; ") + "; ..."
                }

                return EditorCompletionSuggestion(
                    label: entry.name,
                    insertText: entry.name,
                    detail: detail,
                    priority: 920
                )
            }
    }

    /// 生成悬浮提示 Markdown
    static func hoverMarkdown(for className: String, entries: [CSSClassEntry]) -> String? {
        guard let entry = entries.first(where: { $0.name == className }) else { return nil }

        let props = entry.properties.map { "  \($0)" }.joined(separator: ";\n")
        return """
        `\(className)`

        ```css
        .\(className) {
        \(props);
        }
        ```

        Defined in `<style module>` at line \(entry.lineNumber + 1).
        """
    }

    // MARK: - 辅助

    /// 从 CSS 选择器行提取类名
    ///
    /// `.foo .bar {` → ["foo", "bar"]
    /// `.container, .wrapper {` → ["container", "wrapper"]
    private static func extractClassNames(from line: String) -> [String] {
        var names: [String] = []

        // 移除 { } 后的内容
        let beforeBrace: String
        if let braceIndex = line.firstIndex(of: "{") {
            beforeBrace = String(line[line.startIndex..<braceIndex])
        } else {
            beforeBrace = line
        }

        // 按 , 分割选择器组
        let selectors = beforeBrace.split(separator: ",").map(String.init)

        for selector in selectors {
            // 提取 .className
            let pattern = #"\.([a-zA-Z_][\w-]*)"#
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { continue }

            let nsRange = NSRange(selector.startIndex..., in: selector)
            for match in regex.matches(in: selector, range: nsRange) {
                if let range = Range(match.range(at: 1), in: selector) {
                    let name = String(selector[range])
                    if !names.contains(name) {
                        names.append(name)
                    }
                }
            }
        }

        return names
    }

    /// 计算行中的花括号深度变化
    private static func countBraces(in line: String) -> Int {
        var depth = 0
        for char in line {
            if char == "{" { depth += 1 }
            if char == "}" { depth -= 1 }
        }
        return depth
    }
}
