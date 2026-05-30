import Foundation

enum CSVPreviewParser {
    struct ParsedTable: Equatable {
        let headers: [String]
        let rows: [[String]]
    }

    enum ParseError: LocalizedError {
        case emptyData
        case noData

        var errorDescription: String? {
            switch self {
            case .emptyData:
                return String(localized: "Empty CSV data", table: "EditorPreview")
            case .noData:
                return String(localized: "No data rows found", table: "EditorPreview")
            }
        }
    }

    static func parse(_ text: String) throws -> ParsedTable {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ParseError.emptyData
        }

        let separator = detectSeparator(trimmed)
        let lines = parseLines(trimmed, separator: separator)
        guard let headers = lines.first else {
            throw ParseError.noData
        }

        return ParsedTable(headers: headers, rows: Array(lines.dropFirst()))
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

            if char == "\n", !inQuotes {
                break
            }

            if char != "\r" || inQuotes {
                record.append(char)
            }
            index += 1
        }

        return record
    }

    static func parseLines(_ text: String, separator: Character) -> [[String]] {
        var result: [[String]] = []
        var currentLine: [String] = []
        var currentField = ""
        var inQuotes = false

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
                    }
                } else {
                    currentField.append(char)
                }
            } else {
                if char == "\"" {
                    inQuotes = true
                } else if char == separator {
                    currentLine.append(currentField.trimmingCharacters(in: .whitespaces))
                    currentField = ""
                } else if char == "\n" {
                    currentLine.append(currentField.trimmingCharacters(in: .whitespaces))
                    appendNonEmptyLine(currentLine, to: &result)
                    currentLine = []
                    currentField = ""
                } else if char != "\r" {
                    currentField.append(char)
                }
            }
            index += 1
        }

        if !currentField.isEmpty || !currentLine.isEmpty {
            currentLine.append(currentField.trimmingCharacters(in: .whitespaces))
            appendNonEmptyLine(currentLine, to: &result)
        }

        return result
    }

    private static func appendNonEmptyLine(_ line: [String], to result: inout [[String]]) {
        if !line.isEmpty && !(line.count == 1 && line[0].isEmpty) {
            result.append(line)
        }
    }
}
