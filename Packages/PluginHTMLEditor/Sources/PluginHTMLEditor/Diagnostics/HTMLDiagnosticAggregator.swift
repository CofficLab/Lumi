import Foundation
import LanguageServerProtocol

/// HTML 诊断聚合器。
///
/// 当前聚合本地结构诊断，并预留 `merge` 入口给 HTML/CSS/JS LSP 诊断汇总。
public enum HTMLDiagnosticAggregator {
    public static func localDiagnostics(for content: String) -> [Diagnostic] {
        let lines = content.components(separatedBy: "\n")
        var diagnostics: [Diagnostic] = []
        var stack: [TagLocation] = []

        for (lineIndex, line) in lines.enumerated() {
            for tag in tags(in: line, lineIndex: lineIndex) {
                if HTMLKnowledgeBase.voidElements.contains(tag.name) {
                    continue
                }

                if tag.isClosing {
                    if let last = stack.last, last.name == tag.name {
                        stack.removeLast()
                    } else {
                        diagnostics.append(diagnostic(
                            line: tag.startLine,
                            startColumn: tag.startColumn,
                            length: tag.name.utf16.count + 3,
                            severity: .error,
                            message: "Unexpected closing tag </\(tag.name)>."
                        ))
                    }
                } else {
                    stack.append(tag)
                }
            }

            diagnostics.append(contentsOf: imageAccessibilityDiagnostics(in: line, lineIndex: lineIndex))
        }

        for tag in stack {
            diagnostics.append(diagnostic(
                line: tag.startLine,
                startColumn: tag.startColumn,
                length: tag.name.utf16.count + 1,
                severity: .warning,
                message: "Missing closing tag for <\(tag.name)>."
            ))
        }

        return diagnostics
    }

    public static func merge(
        htmlDiagnostics: [Diagnostic],
        cssDiagnostics: [Diagnostic],
        javascriptDiagnostics: [Diagnostic],
        embeddedRegions: [HTMLEmbeddedRegion]
    ) -> [Diagnostic] {
        let mappedCSS = mapEmbedded(cssDiagnostics, language: "css", regions: embeddedRegions)
        let mappedJS = mapEmbedded(javascriptDiagnostics, language: nil, regions: embeddedRegions)
        return deduplicated(htmlDiagnostics + mappedCSS + mappedJS)
    }

    private static func mapEmbedded(
        _ diagnostics: [Diagnostic],
        language: String?,
        regions: [HTMLEmbeddedRegion]
    ) -> [Diagnostic] {
        let matchingRegions = regions.filter { region in
            guard let language else {
                return region.language == "javascript" || region.language == "typescript"
            }
            return region.language == language
        }
        guard let region = matchingRegions.first else { return diagnostics }

        return diagnostics.map { diagnostic in
            let sourceStart = OffsetMapper.toSource(
                virtualLine: diagnostic.range.start.line,
                virtualCharacter: diagnostic.range.start.character,
                region: region
            )
            let sourceEnd = OffsetMapper.toSource(
                virtualLine: diagnostic.range.end.line,
                virtualCharacter: diagnostic.range.end.character,
                region: region
            )
            return Diagnostic(
                range: LSPRange(startPair: sourceStart, endPair: sourceEnd),
                severity: diagnostic.severity,
                code: diagnostic.code,
                codeDescription: diagnostic.codeDescription,
                source: diagnostic.source,
                message: diagnostic.message,
                tags: diagnostic.tags,
                relatedInformation: diagnostic.relatedInformation
            )
        }
    }

    private static func deduplicated(_ diagnostics: [Diagnostic]) -> [Diagnostic] {
        var seen = Set<String>()
        return diagnostics.filter { diagnostic in
            let key = "\(diagnostic.range.start.line):\(diagnostic.range.start.character):\(diagnostic.message)"
            return seen.insert(key).inserted
        }
    }

    private static func imageAccessibilityDiagnostics(in line: String, lineIndex: Int) -> [Diagnostic] {
        let lowercased = line.lowercased()
        guard lowercased.contains("<img"), !lowercased.contains(" alt=") else { return [] }
        let column = line.range(of: "<img").map { line.distance(from: line.startIndex, to: $0.lowerBound) } ?? 0
        return [
            diagnostic(
                line: lineIndex,
                startColumn: column,
                length: 4,
                severity: .hint,
                message: "Image elements should include an alt attribute."
            )
        ]
    }

    private static func tags(in line: String, lineIndex: Int) -> [TagLocation] {
        var result: [TagLocation] = []
        let pattern = #"</?\s*([A-Za-z][A-Za-z0-9:-]*)\b[^>]*?>"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsLine = line as NSString
        let range = NSRange(location: 0, length: nsLine.length)

        for match in regex.matches(in: line, range: range) {
            let tagText = nsLine.substring(with: match.range)
            if tagText.hasPrefix("<!") || tagText.hasPrefix("<?") || tagText.hasSuffix("/>") {
                continue
            }
            let name = nsLine.substring(with: match.range(at: 1)).lowercased()
            result.append(TagLocation(
                name: name,
                startLine: lineIndex,
                startColumn: match.range.location,
                isClosing: tagText.hasPrefix("</")
            ))
        }

        return result
    }

    private static func diagnostic(
        line: Int,
        startColumn: Int,
        length: Int,
        severity: DiagnosticSeverity,
        message: String
    ) -> Diagnostic {
        Diagnostic(
            range: LSPRange(
                start: Position(line: line, character: startColumn),
                end: Position(line: line, character: startColumn + max(length, 1))
            ),
            severity: severity,
            source: "html",
            message: message
        )
    }
}
