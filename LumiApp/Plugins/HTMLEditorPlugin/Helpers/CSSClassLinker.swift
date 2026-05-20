import Foundation

/// HTML `class` 属性与内嵌 CSS 选择器之间的轻量联动。
enum CSSClassLinker {
    struct ClassDefinition: Equatable, Sendable {
        let name: String
        let line: Int
        let column: Int
        let properties: [String]
    }

    static func classDefinitions(in content: String) -> [ClassDefinition] {
        EmbeddedRegionScanner.scanRegions(in: content)
            .filter { $0.language == "css" }
            .flatMap { definitions(in: $0.virtualContent, lineOffset: $0.lineOffset) }
    }

    static func classAttributeNames(in content: String) -> [String] {
        let pattern = #"class\s*=\s*["']([^"']*)["']"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let nsContent = content as NSString
        let range = NSRange(location: 0, length: nsContent.length)
        var names: [String] = []

        for match in regex.matches(in: content, range: range) {
            let value = nsContent.substring(with: match.range(at: 1))
            names.append(contentsOf: value.split(whereSeparator: \.isWhitespace).map(String.init))
        }

        return Array(Set(names)).sorted()
    }

    static func completionSuggestions(prefix: String, content: String) -> [EditorCompletionSuggestion] {
        let normalized = prefix.lowercased()
        return classDefinitions(in: content)
            .filter { normalized.isEmpty || $0.name.lowercased().hasPrefix(normalized) }
            .map { definition in
                let detail = definition.properties.isEmpty
                    ? "CSS class defined in <style>"
                    : definition.properties.prefix(3).joined(separator: "; ")
                return EditorCompletionSuggestion(
                    label: ".\(definition.name)",
                    insertText: definition.name,
                    detail: detail,
                    priority: 910
                )
            }
    }

    static func hoverMarkdown(for className: String, content: String) -> String? {
        let normalized = className.trimmingCharacters(in: CharacterSet(charactersIn: ". \n\t"))
        guard let definition = classDefinitions(in: content).first(where: { $0.name == normalized }) else {
            return nil
        }

        let properties = definition.properties.isEmpty
            ? "  /* no properties captured */"
            : definition.properties.map { "  \($0);" }.joined(separator: "\n")
        return """
        `.\(definition.name)`

        ```css
        .\(definition.name) {
        \(properties)
        }
        ```

        Defined in `<style>` at line \(definition.line + 1).
        """
    }

    private static func definitions(in css: String, lineOffset: Int) -> [ClassDefinition] {
        let lines = css.components(separatedBy: "\n")
        var definitions: [ClassDefinition] = []
        var activeNames: [(name: String, column: Int)] = []
        var activeProperties: [String] = []
        var activeLine = 0
        var braceDepth = 0

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed.hasPrefix("/*") || trimmed.hasPrefix("*") {
                continue
            }

            if activeNames.isEmpty, trimmed.contains(".") {
                activeNames = extractClassNames(from: line)
                activeLine = lineOffset + index
                braceDepth = countBraces(in: line)
                activeProperties = properties(in: line)
                if braceDepth <= 0, line.contains("{"), line.contains("}") {
                    definitions.append(contentsOf: makeDefinitions(activeNames, line: activeLine, properties: activeProperties))
                    activeNames = []
                    activeProperties = []
                }
                continue
            }

            if !activeNames.isEmpty {
                braceDepth += countBraces(in: line)
                activeProperties.append(contentsOf: properties(in: line))
                if braceDepth <= 0 {
                    definitions.append(contentsOf: makeDefinitions(activeNames, line: activeLine, properties: activeProperties))
                    activeNames = []
                    activeProperties = []
                    braceDepth = 0
                }
            }
        }

        var seen = Set<String>()
        return definitions.filter { seen.insert($0.name).inserted }
    }

    private static func makeDefinitions(
        _ names: [(name: String, column: Int)],
        line: Int,
        properties: [String]
    ) -> [ClassDefinition] {
        names.map { ClassDefinition(name: $0.name, line: line, column: $0.column, properties: properties) }
    }

    private static func extractClassNames(from selector: String) -> [(name: String, column: Int)] {
        let pattern = #"\.([A-Za-z_][A-Za-z0-9_-]*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsSelector = selector as NSString
        let range = NSRange(location: 0, length: nsSelector.length)

        return regex.matches(in: selector, range: range).map { match in
            (
                name: nsSelector.substring(with: match.range(at: 1)),
                column: match.range.location
            )
        }
    }

    private static func properties(in line: String) -> [String] {
        line
            .split(separator: ";")
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "{} \t")) }
            .filter { $0.contains(":") && !$0.hasPrefix(".") }
    }

    private static func countBraces(in line: String) -> Int {
        line.reduce(0) { depth, character in
            if character == "{" { return depth + 1 }
            if character == "}" { return depth - 1 }
            return depth
        }
    }
}
