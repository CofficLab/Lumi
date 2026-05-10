import Foundation

/// Markdown 表格规范化器
///
/// 预处理 LLM 输出的 Markdown 表格，修复常见的格式问题，
/// 确保能被 `swift-markdown` / `MarkdownParser` 正确识别为表格块。
///
/// ## 修复的问题
/// 1. **单元格内换行** → 替换为空格（Markdown 表格不支持换行）
/// 2. **缺失分隔线** → 自动补充 `| --- | --- |`
/// 3. **列数不一致** → 补齐空单元格
/// 4. **分隔线格式错误** → 规范化为 `---`
///
/// ## 使用场景
/// - LLM 输出表格时经常因换行/格式化不规范导致 swift-markdown 无法解析
/// - 在 `MarkdownParser.parse()` 入口自动调用，所有消费方无需感知
enum MarkdownTableNormalizer {
    
    // MARK: - Public
    
    /// 规范化 Markdown 内容中的表格格式
    /// - Parameter content: 原始 Markdown 字符串
    /// - Returns: 规范化后的 Markdown 字符串
    static func normalize(_ content: String) -> String {
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false)
        guard !lines.isEmpty else { return content }
        
        var result: [String] = []
        var i = 0
        
        while i < lines.count {
            let line = String(lines[i])
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if isTableLine(trimmed) {
                var tableLines: [String] = []
                var standardTableLineCount = 0
                
                // 收集连续的表格行
                while i < lines.count {
                    let currentLine = String(lines[i])
                    let currentTrimmed = currentLine.trimmingCharacters(in: .whitespaces)
                    
                    if currentTrimmed.isEmpty { break }
                    if isTableLine(currentTrimmed) {
                        tableLines.append(currentLine)
                        standardTableLineCount += 1
                        i += 1
                    } else {
                        break
                    }
                }
                
                // 单行中包含多个管道符并不一定是表格，常见于命令、路径、自然语言说明。
                // Markdown 表格至少需要表头 + 分隔线/数据行，因此只有一行时保持原样，
                // 避免把普通段落误归一化成表格并破坏行内 Markdown（如 **加粗**）。
                guard standardTableLineCount >= 2 else {
                    result.append(contentsOf: tableLines)
                    continue
                }
                
                // 向前探测：收集紧随其后的疑似断裂续行（管道符 < 2 的非空行）
                // 这些行可能是表格数据行因单元格内容换行而断裂
                while i < lines.count {
                    let nextLine = String(lines[i])
                    let nextTrimmed = nextLine.trimmingCharacters(in: .whitespaces)
                    
                    // 空行、新表格行、非空非管道行（看起来不像续行）→ 停止
                    if nextTrimmed.isEmpty { break }
                    if isTableLine(nextTrimmed) { break }
                    
                    // 只含管道符或看起来像续行的内容 → 收集
                    if nextTrimmed.contains("|") || looksLikeContinuation(nextTrimmed, after: tableLines) {
                        tableLines.append(nextLine)
                        i += 1
                    } else {
                        break
                    }
                }
                
                let normalized = normalizeTableBlock(tableLines)
                result.append(contentsOf: normalized)
            } else {
                result.append(line)
                i += 1
            }
        }
        
        return result.joined(separator: "\n")
    }
    
    // MARK: - Internal
    
    /// 判断一行是否为表格相关行（至少 2 个管道符）
    private static func isTableLine(_ line: String) -> Bool {
        line.filter { $0 == "|" }.count >= 2
    }
    
    /// 判断一个非表格行是否像表格数据的断裂续行
    ///
    /// 启发式规则：上一行的最后一个单元格看起来不完整（较短，或以连接性字符结尾）
    private static func looksLikeContinuation(_ line: String, after tableLines: [String]) -> Bool {
        guard !tableLines.isEmpty else { return false }
        let lastLine = tableLines.last!.trimmingCharacters(in: .whitespaces)
        let lastCells = parseTableRow(lastLine)
        
        // 上一行的最后一个单元格内容看起来不完整
        if let lastCell = lastCells.last {
            let trimmed = lastCell.trimmingCharacters(in: .whitespaces)
            // 空单元格 → 不会是续行
            if trimmed.isEmpty { return false }
            // 以连接性字符结尾（箭头、冒号、逗号等）→ 很可能是续行
            let continuationSuffixes = ["->", "→", "::", ":", ".", ","]
            for suffix in continuationSuffixes {
                if trimmed.hasSuffix(suffix) { return true }
            }
        }
        
        return false
    }
    
    /// 判断是否为分隔线行（如 `| --- | --- |` 或 `| :--- | ---: |`）
    private static func isSeparatorLine(_ line: String) -> Bool {
        let normalized = line.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: " ", with: "")
        return normalized.range(of: #"^\|:?-{1,}:?\|"#, options: .regularExpression) != nil
    }
    
    /// 规范化单个表格块
    private static func normalizeTableBlock(_ lines: [String]) -> [String] {
        guard !lines.isEmpty else { return lines }
        let merged = mergeBrokenRows(lines)
        let withSeparator = ensureSeparatorLine(merged)
        return unifyColumnCount(withSeparator)
    }
    
    /// 合并断裂行
    ///
    /// 将因换行断裂的数据行重新拼接到上一行末尾。
    /// 例如：
    /// ```
    /// | A | B |
    /// | C |
    /// 续写内容 |
    /// ```
    /// → `| A | B |` / `| C  续写内容 |`
    private static func mergeBrokenRows(_ lines: [String]) -> [String] {
        guard lines.count > 1 else { return lines }
        
        var result: [String] = [lines[0]]
        var i = 1
        
        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // 分隔线行，直接添加
            if isSeparatorLine(trimmed) {
                result.append(normalizeSeparatorLine(trimmed))
                i += 1
                continue
            }
            
            let pipeCount = trimmed.filter { $0 == "|" }.count
            
            if pipeCount >= 2 {
                // 标准表格行（至少两个管道符），直接添加
                result.append(line)
                i += 1
            } else if !trimmed.isEmpty {
                // 管道符 < 2 的非空行 → 断裂续行，追加到上一行
                if var last = result.last {
                    last = last.trimmingCharacters(in: .whitespaces)
                    if last.hasSuffix("|") {
                        last = String(last.dropLast())
                    }
                    let continuation = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "| "))
                    result[result.count - 1] = last + " " + continuation + " |"
                }
                i += 1
            } else {
                result.append(line)
                i += 1
            }
        }
        
        return result
    }
    
    /// 规范化分隔线格式 → `| --- | --- |`
    private static func normalizeSeparatorLine(_ line: String) -> String {
        let cells = parseTableRow(line)
        let normalized = cells.map { _ in " --- " }
        return "|" + normalized.joined(separator: "|") + "|"
    }
    
    /// 确保表格块中存在分隔线
    private static func ensureSeparatorLine(_ lines: [String]) -> [String] {
        guard !lines.isEmpty else { return lines }
        
        let headerLine = lines[0].trimmingCharacters(in: .whitespaces)
        let colCount = parseTableRow(headerLine).count
        guard colCount >= 2 else { return lines }
        
        // 如果第二行已是分隔线，无需处理
        if lines.count >= 2 && isSeparatorLine(lines[1].trimmingCharacters(in: .whitespaces)) {
            return lines
        }
        
        // 插入分隔线
        let separator = Array(repeating: " --- ", count: colCount).joined(separator: "|")
        return [lines[0], "|" + separator + "|"] + Array(lines.dropFirst())
    }
    
    /// 统一所有行的列数（以标题行为基准）
    private static func unifyColumnCount(_ lines: [String]) -> [String] {
        guard !lines.isEmpty else { return lines }
        
        let targetCount = parseTableRow(lines[0].trimmingCharacters(in: .whitespaces)).count
        guard targetCount >= 2 else { return lines }
        
        return lines.map { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if isSeparatorLine(trimmed) {
                let separator = Array(repeating: " --- ", count: targetCount)
                return "|" + separator.joined(separator: "|") + "|"
            }
            
            var cells = parseTableRow(trimmed)
            while cells.count < targetCount { cells.append("") }
            if cells.count > targetCount { cells = Array(cells.prefix(targetCount)) }
            
            return "|" + cells.map { " \($0) " }.joined(separator: "|") + "|"
        }
    }
    
    /// 解析表格行，提取单元格内容
    private static func parseTableRow(_ line: String) -> [String] {
        let normalized = line
            .trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: CharacterSet(charactersIn: "|"))
        guard !normalized.isEmpty else { return [] }
        return normalized
            .split(separator: "|", omittingEmptySubsequences: false)
            .map { String($0).trimmingCharacters(in: .whitespaces) }
    }
}
