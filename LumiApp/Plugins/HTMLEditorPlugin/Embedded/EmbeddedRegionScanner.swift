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

        regions.append(contentsOf: scanTagRegions(
            in: content,
            lines: lines,
            tagName: "style",
            languageResolver: { _ in "css" }
        ))
        regions.append(contentsOf: scanTagRegions(
            in: content,
            lines: lines,
            tagName: "script",
            languageResolver: scriptLanguage
        ))

        return regions.sorted { $0.startOffset < $1.startOffset }
    }

    /// 获取指定偏移量所处的内嵌语言区域
    static func regionAtOffset(_ offset: Int, in regions: [HTMLEmbeddedRegion]) -> HTMLEmbeddedRegion? {
        return regions.first { $0.contains(offset) }
    }

    // MARK: - 私有方法

    private static func scanTagRegions(
        in content: String,
        lines: [String],
        tagName: String,
        languageResolver: (String) -> String
    ) -> [HTMLEmbeddedRegion] {
        let pattern = "(?is)<\(tagName)\\b([^>]*)>(.*?)</\(tagName)>"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsContent = content as NSString
        let fullRange = NSRange(location: 0, length: nsContent.length)

        return regex.matches(in: content, range: fullRange).compactMap { match in
            guard match.numberOfRanges >= 3 else { return nil }
            let attributes = nsContent.substring(with: match.range(at: 1))
            let bodyRange = match.range(at: 2)
            let body = nsContent.substring(with: bodyRange)
            let startPosition = OffsetMapper.lineAndCharacter(from: bodyRange.location, in: lines)
            return HTMLEmbeddedRegion(
                language: languageResolver(attributes),
                startOffset: bodyRange.location,
                endOffset: bodyRange.location + bodyRange.length,
                virtualContent: body,
                lineOffset: startPosition?.line ?? 0
            )
        }
    }

    private static func scriptLanguage(attributes: String) -> String {
        let normalized = attributes.lowercased()
        if normalized.contains("type=\"text/typescript\"") ||
            normalized.contains("type='text/typescript'") ||
            normalized.contains("type=\"typescript\"") ||
            normalized.contains("type='typescript'") ||
            normalized.contains("lang=\"ts\"") ||
            normalized.contains("lang='ts'") ||
            normalized.contains("lang=\"typescript\"") ||
            normalized.contains("lang='typescript'") {
            return "typescript"
        }
        return "javascript"
    }
}
