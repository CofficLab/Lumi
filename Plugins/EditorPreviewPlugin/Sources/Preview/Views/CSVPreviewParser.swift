import Foundation
import LumiKernel

enum CSVPreviewParser {
    struct ParsedTable: Equatable {
        let headers: [String]
        let rows: [[String]]
    }

    enum ParseError: LocalizedError {
        case emptyData
        case noData
        case unclosedQuote

        var errorDescription: String? {
            switch self {
            case .emptyData:
                return LumiPluginLocalization.string("Empty CSV data", bundle: .module)
            case .noData:
                return LumiPluginLocalization.string("No data rows found", bundle: .module)
            case .unclosedQuote:
                return LumiPluginLocalization.string("Unclosed quoted field", bundle: .module)
            }
        }
    }

    static func parse(_ text: String) throws -> ParsedTable {
        let trimmed = stripByteOrderMark(from: text).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ParseError.emptyData
        }

        let separator = detectSeparator(trimmed)
        let lines = try parseLines(trimmed, separator: separator)
        guard let headers = lines.first else {
            throw ParseError.noData
        }

        return normalizedTable(headers: headers, rows: Array(lines.dropFirst()))
    }

    static func detectSeparator(_ text: String) -> Character {
        let firstLine = firstRecord(in: text)
        var counts: [Character: Int] = [",": 0, "\t": 0, ";": 0]
        var inQuotes = false
        let chars = Array(firstLine)
        var index = 0

        while index < chars.count {
            let char = chars[index]
            if char == "\"" {
                if inQuotes, index + 1 < chars.count, chars[index + 1] == "\"" {
                    index += 1
                } else {
                    inQuotes.toggle()
                }
            } else if !inQuotes, counts.keys.contains(char) {
                counts[char, default: 0] += 1
            }
            index += 1
        }

        if counts["\t", default: 0] > counts[",", default: 0],
           counts["\t", default: 0] > counts[";", default: 0] {
            return "\t"
        } else if counts[";", default: 0] > counts[",", default: 0] {
            return ";"
        }
        return ","
    }

    private static func stripByteOrderMark(from text: String) -> String {
        guard text.first == "\u{FEFF}" else { return text }
        return String(text.dropFirst())
    }

    private static func firstRecord(in text: String) -> String {
        var record = ""
        var inQuotes = false
        let chars = Array(text)
        var index = 0

        while index < chars.count {
            let char = chars[index]

            if char == "\"" {
                if inQuotes, index + 1 < chars.count, chars[index + 1] == "\"" {
                    record.append(char)
                    record.append(chars[index + 1])
                    index += 2
                    continue
                }
                inQuotes.toggle()
            }

            if (char == "\n" || char == "\r"), !inQuotes {
                break
            }

            record.append(char)
            index += 1
        }

        return record
    }

    static func parseLines(_ text: String, separator: Character) throws -> [[String]] {
        var result: [[String]] = []
        var currentLine: [String] = []
        var currentField = ""
        var currentFieldWasQuoted = false
        var inQuotes = false
        var justClosedQuote = false

        let chars = Array(text)
        var index = 0

        while index < chars.count {
            let char = chars[index]

            if inQuotes {
                if char == "\"" {
                    if index + 1 < chars.count && chars[index + 1] == "\"" {
                        currentField.append("\"")
                        index += 1
                    } else {
                        inQuotes = false
                        justClosedQuote = true
                    }
                } else {
                    currentField.append(char)
                }
            } else {
                if char == "\"" {
                    if currentField.trimmingCharacters(in: .whitespaces).isEmpty {
                        currentField = ""
                        currentFieldWasQuoted = true
                    }
                    inQuotes = true
                } else if char == separator {
                    currentLine.append(normalizedField(currentField, wasQuoted: currentFieldWasQuoted))
                    currentField = ""
                    currentFieldWasQuoted = false
                    justClosedQuote = false
                } else if char == "\n" || char == "\r" {
                    currentLine.append(normalizedField(currentField, wasQuoted: currentFieldWasQuoted))
                    appendNonEmptyLine(currentLine, to: &result)
                    currentLine = []
                    currentField = ""
                    currentFieldWasQuoted = false
                    justClosedQuote = false
                    if char == "\r", index + 1 < chars.count, chars[index + 1] == "\n" {
                        index += 1
                    }
                } else if justClosedQuote && (char == " " || char == "\t") {
                    // Ignore padding between a closing quote and the delimiter.
                } else if char != "\r" {
                    currentField.append(char)
                    justClosedQuote = false
                }
            }
            index += 1
        }

        guard !inQuotes else {
            throw ParseError.unclosedQuote
        }

        if !currentField.isEmpty || !currentLine.isEmpty {
            currentLine.append(normalizedField(currentField, wasQuoted: currentFieldWasQuoted))
            appendNonEmptyLine(currentLine, to: &result)
        }

        return result
    }

    private static func normalizedField(_ field: String, wasQuoted: Bool) -> String {
        wasQuoted ? field : field.trimmingCharacters(in: .whitespaces)
    }

    private static func appendNonEmptyLine(_ line: [String], to result: inout [[String]]) {
        if !line.isEmpty && !(line.count == 1 && line[0].isEmpty) {
            result.append(line)
        }
    }

    private static func normalizedTable(headers: [String], rows: [[String]]) -> ParsedTable {
        let columnCount = max(headers.count, rows.map(\.count).max() ?? 0)
        guard columnCount > headers.count else {
            return ParsedTable(headers: headers, rows: rows.map { padded($0, to: columnCount) })
        }

        let extraHeaders = (headers.count..<columnCount).map { "Column \($0 + 1)" }
        return ParsedTable(
            headers: headers + extraHeaders,
            rows: rows.map { padded($0, to: columnCount) }
        )
    }

    private static func padded(_ row: [String], to columnCount: Int) -> [String] {
        guard row.count < columnCount else { return row }
        return row + Array(repeating: "", count: columnCount - row.count)
    }
}
