import Foundation

/// HTML to Markdown 转换器（纯 Swift 实现，无外部依赖）
/// 使用正则表达式和字符串处理实现基本转换
public struct HTMLToMarkdownConverter {

    /// 最大内容长度
    public static let maxContentLength = 100_000
    private static let escapedLessThanPlaceholder = "\u{E000}"
    private static let escapedGreaterThanPlaceholder = "\u{E001}"

    /// 将 HTML 转换为 Markdown
    public static func convert(_ html: String, baseURL: URL? = nil) -> String {
        var result = html

        // 1. 解码 HTML 实体
        result = decodeHTMLEntities(result)

        // 2. 移除不需要的标签
        result = removeUnwantedTags(result)

        // 3. 转换标题
        result = convertHeadings(result)

        // 4. 转换链接和图片
        result = convertLinks(result, baseURL: baseURL)
        result = convertImages(result, baseURL: baseURL)

        // 5. 转换代码块
        result = convertCodeBlocks(result)

        // 6. 转换文本格式
        result = convertTextFormatting(result)

        // 7. 转换列表
        result = convertLists(result)

        // 8. 转换引用块
        result = convertBlockquotes(result)

        // 9. 转换表格
        result = convertTables(result)

        // 10. 处理段落和换行
        result = convertParagraphs(result)

        // 11. 清理
        result = cleanMarkdown(result)
        result = restoreEscapedAngleBrackets(result)

        // 12. 截断
        if result.count > maxContentLength {
            let index = result.index(result.startIndex, offsetBy: maxContentLength)
            result = String(result[..<index]) + "\n\n[Content truncated due to length...]"
        }

        return result
    }

    // MARK: - HTML Entity Decoding

    private static func decodeHTMLEntities(_ text: String) -> String {
        var result = text

        let entities: [String: String] = [
            "&amp;": "&",
            "&lt;": escapedLessThanPlaceholder,
            "&gt;": escapedGreaterThanPlaceholder,
            "&quot;": "\"",
            "&apos;": "'",
            "&nbsp;": " ",
            "&#39;": "'",
            "&mdash;": "—",
            "&ndash;": "–",
            "&hellip;": "...",
            "&rsquo;": "'",
            "&lsquo;": "'",
            "&rdquo;": "\"",
            "&ldquo;": "\"",
            "&copy;": "©",
            "&reg;": "®",
            "&trade;": "™",
        ]

        for (entity, char) in entities {
            result = result.replacingOccurrences(of: entity, with: char)
        }

        // 解码数字实体 (如 &#60; / &#x3c; -> <)
        let numericPattern = #"&#(?:[xX]([0-9a-fA-F]+)|(\d+));"#
        while let match = result.range(of: numericPattern, options: .regularExpression) {
            let entityStr = String(result[match])
            let groups = entityStr.matchingStrings(for: numericPattern).first
            let hexString = groups?.dropFirst().first { !$0.isEmpty }
            let radix = entityStr.lowercased().hasPrefix("&#x") ? 16 : 10
            if let numStr = hexString,
               let num = Int(numStr, radix: radix) {
                if num == 60 {
                    result.replaceSubrange(match, with: escapedLessThanPlaceholder)
                } else if num == 62 {
                    result.replaceSubrange(match, with: escapedGreaterThanPlaceholder)
                } else if let scalar = UnicodeScalar(num) {
                    result.replaceSubrange(match, with: String(scalar))
                } else {
                    break
                }
            } else {
                break
            }
        }

        return result
    }

    // MARK: - Tag Removal

    private static func removeUnwantedTags(_ html: String) -> String {
        var result = html

        // 移除 script, style, noscript, iframe 等标签及其内容
        let removePatterns = [
            "(?s)<script[^>]*>.*?</script>",
            "(?s)<style[^>]*>.*?</style>",
            "(?s)<noscript[^>]*>.*?</noscript>",
            "(?s)<iframe[^>]*>.*?</iframe>",
            "(?s)<svg[^>]*>.*?</svg>",
            "(?s)<!--.*?-->",
        ]

        for pattern in removePatterns {
            result = result.replacingOccurrences(
                of: pattern,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
        }

        // 移除 nav, footer, sidebar 等容器（保留内容）
        let unwrapPatterns = [
            "<nav[^>]*>", "</nav>",
            "<footer[^>]*>", "</footer>",
            "<aside[^>]*>", "</aside>",
            "<header[^>]*>", "</header>",
        ]

        for pattern in unwrapPatterns {
            result = result.replacingOccurrences(
                of: pattern,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
        }

        return result
    }

    // MARK: - Heading Conversion

    private static func convertHeadings(_ html: String) -> String {
        var result = html

        for level in 1...6 {
            let openPattern = "<h\(level)[^>]*>"
            let closePattern = "</h\(level)>"

            result = result.replacingOccurrences(
                of: openPattern,
                with: "\n\(String(repeating: "#", count: level)) ",
                options: [.regularExpression, .caseInsensitive]
            )
            result = result.replacingOccurrences(
                of: closePattern,
                with: "\n\n",
                options: [.regularExpression, .caseInsensitive]
            )
        }

        return result
    }

    // MARK: - Link Conversion

    private static func convertLinks(_ html: String, baseURL: URL?) -> String {
        let pattern = #"(?s)<a\b[^>]*>(.*?)</a>"#

        var result = html

        while let match = result.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
            let linkStr = String(result[match])
            let groups = linkStr.matchingStrings(for: pattern)

            if let groups = groups.first, groups.count >= 2 {
                let text = groups[1]
                guard let href = attributeValue(named: "href", in: linkStr) else {
                    result.replaceSubrange(match, with: text)
                    continue
                }

                // 解码链接文本中的标签
                let cleanText = stripHTMLTags(text).normalizedInlineWhitespace
                let absoluteHref = resolveURL(href, baseURL: baseURL)

                let markdownLink = "[\(cleanText)](\(absoluteHref))"
                result.replaceSubrange(match, with: markdownLink)
            } else {
                break
            }
        }

        // 处理没有 href 的链接
        result = result.replacingOccurrences(
            of: #"(?s)<a[^>]*>(.*?)</a>"#,
            with: "$1",
            options: [.regularExpression, .caseInsensitive]
        )

        return result
    }

    // MARK: - Image Conversion

    private static func convertImages(_ html: String, baseURL: URL?) -> String {
        let pattern = #"<img\b[^>]*>"#
        var result = html

        while let match = result.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
            let imgStr = String(result[match])
            guard let src = attributeValue(named: "src", in: imgStr) else {
                result.replaceSubrange(match, with: "")
                continue
            }

            let alt = attributeValue(named: "alt", in: imgStr)?.trimmed
            let absoluteSrc = resolveURL(src, baseURL: baseURL)
            let markdownImg = "![\(alt?.isEmpty == false ? alt! : "image")](\(absoluteSrc))"
            result.replaceSubrange(match, with: markdownImg)
        }

        return result
    }

    // MARK: - Text Formatting

    private static func convertTextFormatting(_ html: String) -> String {
        var result = html

        // 粗体
        result = result.replacingOccurrences(
            of: #"<strong[^>]*>(.*?)</strong>"#,
            with: "**$1**",
            options: [.regularExpression, .caseInsensitive]
        )
        result = result.replacingOccurrences(
            of: #"<b[^>]*>(.*?)</b>"#,
            with: "**$1**",
            options: [.regularExpression, .caseInsensitive]
        )

        // 斜体
        result = result.replacingOccurrences(
            of: #"<em[^>]*>(.*?)</em>"#,
            with: "*$1*",
            options: [.regularExpression, .caseInsensitive]
        )
        result = result.replacingOccurrences(
            of: #"<i[^>]*>(.*?)</i>"#,
            with: "*$1*",
            options: [.regularExpression, .caseInsensitive]
        )

        // 删除线
        result = result.replacingOccurrences(
            of: #"<s[^>]*>(.*?)</s>"#,
            with: "~~$1~~",
            options: [.regularExpression, .caseInsensitive]
        )
        result = result.replacingOccurrences(
            of: #"<del[^>]*>(.*?)</del>"#,
            with: "~~$1~~",
            options: [.regularExpression, .caseInsensitive]
        )
        result = result.replacingOccurrences(
            of: #"<strike[^>]*>(.*?)</strike>"#,
            with: "~~$1~~",
            options: [.regularExpression, .caseInsensitive]
        )

        // 内联代码
        result = result.replacingOccurrences(
            of: #"<code[^>]*>(.*?)</code>"#,
            with: "`$1`",
            options: [.regularExpression, .caseInsensitive]
        )

        // kbd
        result = result.replacingOccurrences(
            of: #"<kbd[^>]*>(.*?)</kbd>"#,
            with: "`$1`",
            options: [.regularExpression, .caseInsensitive]
        )

        return result
    }

    // MARK: - List Conversion

    private static func convertLists(_ html: String) -> String {
        var result = html

        // 无序列表
        result = convertUnorderedList(result)

        // 有序列表
        result = convertOrderedLists(result)

        // 移除 li 标签
        result = result.replacingOccurrences(
            of: #"<li[^>]*>"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        result = result.replacingOccurrences(
            of: "</li>",
            with: "\n",
            options: [.caseInsensitive]
        )

        return result
    }

    private static func convertUnorderedList(_ html: String) -> String {
        var result = html

        // 处理 ul 标签
        while let match = result.range(of: "<ul[^>]*>", options: [.regularExpression, .caseInsensitive]) {
            // 找到对应的闭合标签
            let openStart = match.lowerBound
            var depth = 1
            var closeEnd = result.endIndex

            // 查找匹配的 </ul>
            var searchStart = match.upperBound
            while depth > 0 && searchStart < result.endIndex {
                if let nextOpen = result.range(of: "<ul[^>]*>", options: [.regularExpression, .caseInsensitive], range: searchStart..<result.endIndex) {
                    if let nextClose = result.range(of: "</ul>", options: .caseInsensitive, range: searchStart..<nextOpen.lowerBound) {
                        depth -= 1
                        closeEnd = nextClose.upperBound
                        searchStart = nextClose.upperBound
                    } else {
                        depth += 1
                        searchStart = nextOpen.upperBound
                    }
                } else if let nextClose = result.range(of: "</ul>", options: .caseInsensitive, range: searchStart..<result.endIndex) {
                    depth -= 1
                    closeEnd = nextClose.upperBound
                    searchStart = nextClose.upperBound
                } else {
                    break
                }
            }

            if depth == 0 {
                // 提取列表内容并添加前缀
                let listContent = String(result[match.upperBound..<closeEnd])
                let items = convertListItems(in: listContent) { _, content in
                    "- " + stripHTMLTags(content).trimmed
                }

                result.replaceSubrange(openStart..<closeEnd, with: "\n" + items + "\n\n")
            } else {
                // 简化处理，直接替换开标签
                result.replaceSubrange(match, with: "\n")
                if let closeMatch = result.range(of: "</ul>", options: .caseInsensitive) {
                    result.replaceSubrange(closeMatch, with: "\n\n")
                }
            }
        }

        return result
    }

    private static func convertOrderedLists(_ html: String) -> String {
        var result = html

        while let match = result.range(of: "<ol[^>]*>", options: [.regularExpression, .caseInsensitive]) {
            // 找到下一个 </ol>
            if let closeMatch = result.range(
                of: "</ol>",
                options: .caseInsensitive,
                range: match.upperBound..<result.endIndex
            ) {
                // 获取列表项并添加编号
                let openingTag = String(result[match])
                let startNumber = attributeValue(named: "start", in: openingTag)
                    .flatMap { Int($0.trimmed) } ?? 1
                let listContent = String(result[match.upperBound..<closeMatch.lowerBound])
                let items = convertListItems(in: listContent) { index, content in
                    "\(startNumber + index). " + stripHTMLTags(content).trimmed
                }

                result.replaceSubrange(match.lowerBound..<closeMatch.upperBound, with: "\n" + items + "\n\n")
            } else {
                result.replaceSubrange(match, with: "\n")
            }
        }

        return result
    }

    private static func convertListItems(
        in listContent: String,
        formatter: (Int, String) -> String
    ) -> String {
        let pattern = #"<li\b[^>]*>(.*?)</li>"#
        if let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) {
            let nsRange = NSRange(listContent.startIndex..<listContent.endIndex, in: listContent)
            let matches = regex.matches(in: listContent, range: nsRange)
            if !matches.isEmpty {
                return matches.enumerated()
                    .compactMap { index, match -> String? in
                        guard let contentRange = Range(match.range(at: 1), in: listContent) else {
                            return nil
                        }
                        return formatter(index, String(listContent[contentRange]))
                    }
                    .joined(separator: "\n")
            }
        }

        return listContent.components(separatedBy: "<li")
            .dropFirst()
            .enumerated()
            .compactMap { index, item -> String? in
                guard let tagEnd = item.range(of: ">") else {
                    return nil
                }

                let content = String(item[tagEnd.upperBound...])
                let contentBeforeClose = content.range(of: "</li>", options: .caseInsensitive)
                    .map { String(content[..<$0.lowerBound]) } ?? content
                let trimmedContent = contentBeforeClose.trimmed

                guard !trimmedContent.isEmpty else {
                    return nil
                }

                return formatter(index, trimmedContent)
            }
            .joined(separator: "\n")
    }

    // MARK: - Code Block Conversion

    private static func convertCodeBlocks(_ html: String) -> String {
        var result = html

        // pre 标签
        let pattern = #"(?s)<pre[^>]*>(.*?)</pre>"#

        while let match = result.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
            let codeStr = String(result[match])
            let groups = codeStr.matchingStrings(for: pattern)

            if let groups = groups.first, groups.count >= 2 {
                let code = groups[1]
                // 移除内部 code 标签
                let cleanCode = stripHTMLTags(code)
                let codeBlock = "\n```\n\(cleanCode)\n```\n\n"
                result.replaceSubrange(match, with: codeBlock)
            } else {
                break
            }
        }

        return result
    }

    // MARK: - Blockquote Conversion

    private static func convertBlockquotes(_ html: String) -> String {
        var result = html
        let pattern = #"(?s)<blockquote[^>]*>(.*?)</blockquote>"#

        while let match = result.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
            let quoteStr = String(result[match])
            let groups = quoteStr.matchingStrings(for: pattern)

            if let groups = groups.first, groups.count >= 2 {
                let content = groups[1]
                let quoteMarkdown = convertParagraphs(content)
                let cleanContent = stripHTMLTags(quoteMarkdown).trimmed
                let lines = cleanContent
                    .components(separatedBy: "\n")
                    .map { $0.trimmed }
                    .filter { !$0.isEmpty }
                let quotedLines = lines.map { "> \($0)" }.joined(separator: "\n")
                result.replaceSubrange(match, with: "\n" + quotedLines + "\n\n")
            } else {
                break
            }
        }

        return result
    }

    // MARK: - Table Conversion

    private static func convertTables(_ html: String) -> String {
        var result = html

        // 简化的表格处理
        while let tableMatch = result.range(of: "<table[^>]*>", options: [.regularExpression, .caseInsensitive]) {
            // 找到表格结束
            if let tableEnd = result.range(of: "</table>", options: .caseInsensitive, range: tableMatch.upperBound..<result.endIndex) {
                let tableContent = String(result[tableMatch.upperBound..<tableEnd.lowerBound])

                // 提取行
                var rows: [[String]] = []
                let rowPattern = #"<tr[^>]*>(.*?)</tr>"#
                let rowMatches = tableContent.matchingStrings(for: rowPattern)

                for rowMatch in rowMatches {
                    if rowMatch.count >= 2 {
                        let cellsPattern = #"<td[^>]*>(.*?)</td>|<th[^>]*>(.*?)</th>"#
                        let cellMatches = rowMatch[1].matchingStrings(for: cellsPattern)
                        var cells: [String] = []
                        for cellMatch in cellMatches {
                            // td 或 th 的内容
                            var content = ""
                            if cellMatch.count > 2 {
                                content = cellMatch[1].isEmpty ? cellMatch[2] : cellMatch[1]
                            } else if cellMatch.count > 1 {
                                content = cellMatch[1]
                            }
                            cells.append(escapeMarkdownTableCell(stripHTMLTags(content).trimmed))
                        }
                        if !cells.isEmpty {
                            rows.append(cells)
                        }
                    }
                }

                // 生成 Markdown 表格
                var markdownTable = ""
                if !rows.isEmpty {
                    // 第一行作为表头
                    let header = rows[0]
                    markdownTable = "| " + header.joined(separator: " | ") + " |\n"
                    markdownTable += "| " + header.map { _ in "---" }.joined(separator: " | ") + " |\n"

                    for row in rows.dropFirst() {
                        // 补齐列数
                        var paddedRow = row
                        while paddedRow.count < header.count {
                            paddedRow.append("")
                        }
                        markdownTable += "| " + paddedRow.prefix(header.count).joined(separator: " | ") + " |\n"
                    }
                }

                result.replaceSubrange(tableMatch.lowerBound..<tableEnd.upperBound, with: "\n" + markdownTable + "\n")
            } else {
                // 没找到结束标签，移除开标签
                result.replaceSubrange(tableMatch, with: "")
            }
        }

        return result
    }

    // MARK: - Paragraph Conversion

    private static func convertParagraphs(_ html: String) -> String {
        var result = html

        // p 标签
        result = result.replacingOccurrences(
            of: #"<p[^>]*>"#,
            with: "\n",
            options: [.regularExpression, .caseInsensitive]
        )
        result = result.replacingOccurrences(
            of: "</p>",
            with: "\n\n",
            options: .caseInsensitive
        )

        // br 标签
        result = result.replacingOccurrences(
            of: #"<br[^>]*/?>"#,
            with: "\n",
            options: [.regularExpression, .caseInsensitive]
        )

        // hr 标签
        result = result.replacingOccurrences(
            of: #"<hr[^>]*/?>"#,
            with: "\n---\n",
            options: [.regularExpression, .caseInsensitive]
        )

        // div 标签
        result = result.replacingOccurrences(
            of: #"<div[^>]*>"#,
            with: "\n",
            options: [.regularExpression, .caseInsensitive]
        )
        result = result.replacingOccurrences(
            of: "</div>",
            with: "\n",
            options: .caseInsensitive
        )

        // section 标签
        result = result.replacingOccurrences(
            of: #"<section[^>]*>"#,
            with: "\n",
            options: [.regularExpression, .caseInsensitive]
        )
        result = result.replacingOccurrences(
            of: "</section>",
            with: "\n",
            options: .caseInsensitive
        )

        return result
    }

    // MARK: - Cleanup

    private static func cleanMarkdown(_ markdown: String) -> String {
        var result = markdown

        // 移除剩余的 HTML 标签
        result = stripHTMLTags(result)

        // 移除多余的空行
        while result.contains("\n\n\n") {
            result = result.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }

        // 清理行首空白
        result = result.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: "\n")

        // 移除首尾空白
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)

        return result
    }

    private static func restoreEscapedAngleBrackets(_ markdown: String) -> String {
        markdown
            .replacingOccurrences(of: escapedLessThanPlaceholder, with: "<")
            .replacingOccurrences(of: escapedGreaterThanPlaceholder, with: ">")
    }

    private static func escapeMarkdownTableCell(_ text: String) -> String {
        text.replacingOccurrences(of: "|", with: #"\|"#)
    }

    // MARK: - Helper Methods

    /// 移除所有 HTML 标签
    private static func stripHTMLTags(_ text: String) -> String {
        return text.replacingOccurrences(
            of: #"<[^>]+>"#,
            with: "",
            options: .regularExpression
        )
    }

    /// 解析相对 URL
    private static func resolveURL(_ url: String, baseURL: URL?) -> String {
        guard let baseURL = baseURL else { return url }

        let normalizedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        if let absoluteURL = URL(string: normalizedURL),
           let scheme = absoluteURL.scheme?.lowercased(),
           scheme == "http" || scheme == "https" {
            return normalizedURL
        }

        if normalizedURL.hasPrefix("//"),
           let scheme = baseURL.scheme,
           let protocolRelativeURL = URL(string: "\(scheme):\(normalizedURL)") {
            return protocolRelativeURL.absoluteString
        }

        if let resolvedURL = URL(string: normalizedURL, relativeTo: baseURL) {
            return resolvedURL.absoluteString
        }

        return url
    }

    private static func attributeValue(named name: String, in tag: String) -> String? {
        let escapedName = NSRegularExpression.escapedPattern(for: name)
        let pattern = #"\b"# + escapedName + #"\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'=<>`]+))"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }

        let nsRange = NSRange(tag.startIndex..<tag.endIndex, in: tag)
        guard let match = regex.firstMatch(in: tag, range: nsRange) else {
            return nil
        }

        for rangeIndex in 1..<match.numberOfRanges {
            let range = match.range(at: rangeIndex)
            guard range.location != NSNotFound,
                  let swiftRange = Range(range, in: tag) else {
                continue
            }
            return String(tag[swiftRange])
        }

        return nil
    }
}

// MARK: - String Extension for Regex Matching

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var normalizedInlineWhitespace: String {
        components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// 获取正则表达式匹配的所有组
    func matchingStrings(for pattern: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return []
        }

        let nsRange = NSRange(startIndex..<endIndex, in: self)
        let matches = regex.matches(in: self, options: [], range: nsRange)

        return matches.map { match in
            var groups: [String] = []
            for i in 0..<match.numberOfRanges {
                let range = match.range(at: i)
                if range.location != NSNotFound {
                    if let swiftRange = Range(range, in: self) {
                        groups.append(String(self[swiftRange]))
                    }
                }
            }
            return groups
        }
    }
}
