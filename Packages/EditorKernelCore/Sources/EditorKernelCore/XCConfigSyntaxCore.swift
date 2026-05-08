import Foundation

public enum XCConfigSyntaxCore {
    public struct IncludeDirective: Equatable {
        public let path: String
        public let pathRange: NSRange

        public init(path: String, pathRange: NSRange) {
            self.path = path
            self.pathRange = pathRange
        }
    }

    public struct KeyOccurrence: Equatable {
        public let key: String
        public let range: NSRange
        public let line: Int

        public init(key: String, range: NSRange, line: Int) {
            self.key = key
            self.range = range
            self.line = line
        }
    }

    public enum TokenType: String {
        case comment = "comment"
        case include = "include"
        case key = "key"
        case value = "value"
        case operatorSymbol = "operator"
        case preprocessor = "preprocessor"
        case string = "string"
    }

    public struct Token {
        public let type: TokenType
        public let range: NSRange

        public init(type: TokenType, range: NSRange) {
            self.type = type
            self.range = range
        }
    }

    public static func tokenize(_ content: String) -> [Token] {
        var tokens: [Token] = []
        let nsContent = content as NSString

        let commentPattern = "(?://[^\\n]*)|(?:/\\*[\\s\\S]*?\\*/)"
        addTokens(for: commentPattern, in: content, nsContent: nsContent, type: .comment, to: &tokens)

        let includePattern = "^\\s*#include(?:_once)?\\s+\"([^\"]+)\""
        addTokens(for: includePattern, in: content, nsContent: nsContent, type: .include, to: &tokens)

        let keyValuePattern = "^\\s*([A-Za-z_][A-Za-z0-9_]*)\\s*([=+-]=?)\\s*(.+)$"
        if let regex = try? NSRegularExpression(pattern: keyValuePattern, options: .anchorsMatchLines) {
            regex.enumerateMatches(in: content, range: NSRange(location: 0, length: content.utf16.count)) { match, _, _ in
                guard let match else { return }
                let keyRange = match.range(at: 1)
                if keyRange.location != NSNotFound {
                    tokens.append(Token(type: .key, range: keyRange))
                }
                let opRange = match.range(at: 2)
                if opRange.location != NSNotFound {
                    tokens.append(Token(type: .operatorSymbol, range: opRange))
                }
                let valueRange = match.range(at: 3)
                if valueRange.location != NSNotFound {
                    tokens.append(Token(type: .value, range: valueRange))
                }
            }
        }

        let variablePattern = "\\$[({][A-Za-z_][A-Za-z0-9_]*[)}]"
        addTokens(for: variablePattern, in: content, nsContent: nsContent, type: .preprocessor, to: &tokens)

        let stringPattern = "\"[^\"]*\""
        addTokens(for: stringPattern, in: content, nsContent: nsContent, type: .string, to: &tokens)

        return tokens.sorted { $0.range.location < $1.range.location }
    }

    public static func includeDirective(
        at location: Int,
        in content: String
    ) -> IncludeDirective? {
        let nsRange = NSRange(location: 0, length: content.utf16.count)
        let pattern = #"(?m)^\s*#include(?:_once)?\s+"([^"]+)""#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }

        for match in regex.matches(in: content, range: nsRange) {
            let pathRange = match.range(at: 1)
            guard pathRange.location != NSNotFound else { continue }
            let extendedRange = NSRange(location: pathRange.location - 1, length: pathRange.length + 2)
            guard NSLocationInRange(location, extendedRange),
                  let swiftRange = Range(pathRange, in: content) else { continue }
            return IncludeDirective(path: String(content[swiftRange]), pathRange: pathRange)
        }
        return nil
    }

    public static func resolveIncludedFileURL(
        for directive: IncludeDirective,
        currentFileURL: URL
    ) -> URL? {
        let candidate = currentFileURL.deletingLastPathComponent()
            .appendingPathComponent(directive.path)
            .standardizedFileURL
        return FileManager.default.fileExists(atPath: candidate.path) ? candidate : nil
    }

    public static func keyOccurrences(in content: String) -> [KeyOccurrence] {
        let pattern = #"(?m)^\s*([A-Za-z_][A-Za-z0-9_]*)\s*([=+-]=?)\s*(.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsRange = NSRange(location: 0, length: content.utf16.count)
        return regex.matches(in: content, range: nsRange).compactMap { match in
            let keyRange = match.range(at: 1)
            guard keyRange.location != NSNotFound,
                  let swiftRange = Range(keyRange, in: content) else {
                return nil
            }
            return KeyOccurrence(
                key: String(content[swiftRange]),
                range: keyRange,
                line: lineNumber(for: keyRange.location, in: content)
            )
        }
    }

    private static func addTokens(
        for pattern: String,
        in content: String,
        nsContent: NSString,
        type: TokenType,
        to tokens: inout [Token]
    ) {
        _ = nsContent
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .anchorsMatchLines) else { return }
        regex.enumerateMatches(in: content, range: NSRange(location: 0, length: content.utf16.count)) { match, _, _ in
            guard let match else { return }
            let range = match.range(at: 0)
            tokens.append(Token(type: type, range: range))
        }
    }

    private static func lineNumber(for utf16Offset: Int, in content: String) -> Int {
        var line = 1
        var offset = 0
        for scalar in content.utf16 {
            if offset >= utf16Offset { break }
            if scalar == 10 { line += 1 }
            offset += 1
        }
        return line
    }
}
