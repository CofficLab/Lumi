import Foundation

enum ReadFileLineReader {
    static let defaultLineLimit = 250
    static let maxLineLimit = 250

    struct Request: Equatable {
        let offset: Int?
        let limit: Int?
    }

    struct Result: Equatable {
        let formattedContent: String
        let startLine: Int
        let endLine: Int
        let totalLines: Int
    }

    static func lines(in content: String) -> [String] {
        guard !content.isEmpty else { return [] }

        var lines = content.components(separatedBy: "\n")
        if lines.last == "" {
            lines.removeLast()
        }
        return lines
    }

    static func read(content: String, request: Request) -> Result {
        let allLines = lines(in: content)
        let totalLines = allLines.count
        let lineLimit = normalizedLimit(request.limit)

        guard totalLines > 0 else {
            return Result(
                formattedContent: "",
                startLine: 0,
                endLine: 0,
                totalLines: 0
            )
        }

        let startLine = resolveStartLine(offset: request.offset, totalLines: totalLines)
        let endLine = min(startLine + lineLimit - 1, totalLines)
        let selectedLines = Array(allLines[(startLine - 1)..<endLine])
        let formatted = formatLines(selectedLines, startLine: startLine, endLine: endLine, totalLines: totalLines)

        return Result(
            formattedContent: formatted,
            startLine: startLine,
            endLine: endLine,
            totalLines: totalLines
        )
    }

    private static func normalizedLimit(_ limit: Int?) -> Int {
        let requested = limit ?? defaultLineLimit
        return min(max(1, requested), maxLineLimit)
    }

    private static func resolveStartLine(offset: Int?, totalLines: Int) -> Int {
        guard let offset else { return 1 }

        if offset < 0 {
            return min(totalLines, max(1, totalLines + offset + 1))
        }

        return min(max(1, offset), totalLines)
    }

    private static func formatLines(
        _ lines: [String],
        startLine: Int,
        endLine: Int,
        totalLines: Int
    ) -> String {
        let width = max(String(totalLines).count, String(endLine).count)
        var output = lines.enumerated().map { index, line in
            let lineNumber = startLine + index
            let prefix = paddedLineNumber(lineNumber, width: width)
            return "\(prefix)|\(line)"
        }.joined(separator: "\n")

        if endLine < totalLines {
            let nextOffset = endLine + 1
            output += "\n\n[Showing lines \(startLine)-\(endLine) of \(totalLines). Use offset=\(nextOffset) with limit to read more.]"
        }

        return output
    }

    private static func paddedLineNumber(_ lineNumber: Int, width: Int) -> String {
        let text = String(lineNumber)
        guard text.count < width else { return text }
        return String(repeating: " ", count: width - text.count) + text
    }
}
