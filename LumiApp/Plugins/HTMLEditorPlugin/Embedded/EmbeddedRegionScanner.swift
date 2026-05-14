import Foundation

/// HTML 内嵌语言区域定义
struct HTMLEmbeddedRegion: Equatable, Sendable {
    /// 语言类型
    let language: String
    /// 起始偏移量（在源文档中）
    let startOffset: Int
    /// 结束偏移量（在源文档中）
    let endOffset: Int
    /// 虚拟文档内容
    let virtualContent: String
    /// 行偏移（虚拟文档起始行号）
    let lineOffset: Int

    /// 检查给定偏移量是否在此区域内
    func contains(_ offset: Int) -> Bool {
        return offset >= startOffset && offset < endOffset
    }

    /// 将源文档偏移量转换为虚拟文档偏移量
    func toVirtualOffset(_ offset: Int) -> Int {
        return offset - startOffset
    }

    /// 将虚拟文档偏移量转换为源文档偏移量
    func toSourceOffset(_ virtualOffset: Int) -> Int {
        return virtualOffset + startOffset
    }
}

/// 内嵌语言区域扫描器
enum EmbeddedRegionScanner {
    /// 扫描 HTML 文档中的所有内嵌语言区域
    ///
    /// - Parameter content: HTML 文档内容
    /// - Returns: 内嵌语言区域数组
    static func scanRegions(in content: String) -> [HTMLEmbeddedRegion] {
        var regions: [HTMLEmbeddedRegion] = []
        let lines = content.components(separatedBy: .newlines)
        var currentOffset = 0

        var i = 0
        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // 检测 <style> 区域
            if let region = detectStyleRegion(lines: lines, startIndex: i, currentOffset: currentOffset) {
                regions.append(region)
                currentOffset += region.endOffset - region.startOffset
                i = lineOffset(for: region.endOffset, in: lines)
                continue
            }

            // 检测 <script> 区域
            if let region = detectScriptRegion(lines: lines, startIndex: i, currentOffset: currentOffset) {
                regions.append(region)
                currentOffset += region.endOffset - region.startOffset
                i = lineOffset(for: region.endOffset, in: lines)
                continue
            }

            currentOffset += line.utf16.count + 1 // +1 for newline
            i += 1
        }

        return regions
    }

    /// 获取指定偏移量所处的内嵌语言区域
    static func regionAtOffset(_ offset: Int, in regions: [HTMLEmbeddedRegion]) -> HTMLEmbeddedRegion? {
        return regions.first { $0.contains(offset) }
    }

    // MARK: - 私有方法

    private static func detectStyleRegion(lines: [String], startIndex: Int, currentOffset: Int) -> HTMLEmbeddedRegion? {
        let line = lines[startIndex]
        let lowercased = line.lowercased()

        // 匹配 <style 或 <style>
        guard lowercased.contains("<style") else { return nil }

        // 找到开始位置
        let startOffset = currentOffset

        // 收集内容直到 </style>
        var virtualLines: [String] = []
        var j = startIndex
        var foundEnd = false
        var totalOffset = currentOffset

        while j < lines.count {
            let currentLine = lines[j]
            let currentLower = currentLine.lowercased()

            if currentLower.contains("</style>") {
                // 提取 </style> 之前的内容
                if let endIdx = currentLower.range(of: "</style>") {
                    let beforeEnd = String(currentLine[currentLine.startIndex..<endIdx.lowerBound])
                    if !beforeEnd.trimmingCharacters(in: .whitespaces).isEmpty {
                        virtualLines.append(beforeEnd)
                    }
                }
                totalOffset += currentLine.utf16.count + 1
                foundEnd = true
                j += 1
                break
            } else {
                virtualLines.append(currentLine)
                totalOffset += currentLine.utf16.count + 1
            }
            j += 1
        }

        guard foundEnd else { return nil }

        let virtualContent = virtualLines.joined(separator: "\n")
        return HTMLEmbeddedRegion(
            language: "css",
            startOffset: startOffset,
            endOffset: totalOffset,
            virtualContent: virtualContent,
            lineOffset: startIndex
        )
    }

    private static func detectScriptRegion(lines: [String], startIndex: Int, currentOffset: Int) -> HTMLEmbeddedRegion? {
        let line = lines[startIndex]
        let lowercased = line.lowercased()

        // 匹配 <script 或 <script>
        guard lowercased.contains("<script") else { return nil }

        // 确定语言类型
        var language = "javascript"
        if lowercased.contains("type=\"text/typescript\"") || lowercased.contains("type=\"typescript\"") {
            language = "typescript"
        } else if lowercased.contains("lang=\"ts\"") {
            language = "typescript"
        }

        let startOffset = currentOffset

        var virtualLines: [String] = []
        var j = startIndex
        var foundEnd = false
        var totalOffset = currentOffset

        while j < lines.count {
            let currentLine = lines[j]
            let currentLower = currentLine.lowercased()

            if currentLower.contains("</script>") {
                if let endIdx = currentLower.range(of: "</script>") {
                    let beforeEnd = String(currentLine[currentLine.startIndex..<endIdx.lowerBound])
                    if !beforeEnd.trimmingCharacters(in: .whitespaces).isEmpty {
                        virtualLines.append(beforeEnd)
                    }
                }
                totalOffset += currentLine.utf16.count + 1
                foundEnd = true
                j += 1
                break
            } else {
                virtualLines.append(currentLine)
                totalOffset += currentLine.utf16.count + 1
            }
            j += 1
        }

        guard foundEnd else { return nil }

        let virtualContent = virtualLines.joined(separator: "\n")
        return HTMLEmbeddedRegion(
            language: language,
            startOffset: startOffset,
            endOffset: totalOffset,
            virtualContent: virtualContent,
            lineOffset: startIndex
        )
    }

    private static func lineOffset(for offset: Int, in lines: [String]) -> Int {
        var current = 0
        for (index, line) in lines.enumerated() {
            current += line.utf16.count + 1
            if current >= offset {
                return index + 1
            }
        }
        return lines.count
    }
}
