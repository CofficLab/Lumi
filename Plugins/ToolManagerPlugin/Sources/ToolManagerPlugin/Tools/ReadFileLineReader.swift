import Foundation

enum ReadFileLineReader {
    static let defaultLineLimit = 250
    static let maxLineLimit = 250
    static let maxOutputBytes = 512 * 1024
    static let maxLineBytes = 128 * 1024
    static let fastPathMaxFileBytes = 10 * 1024 * 1024

    struct Request: Equatable, Sendable {
        let offset: Int?
        let limit: Int?
    }

    struct Result: Equatable, Sendable {
        let formattedContent: String
        let startLine: Int
        let endLine: Int
        let totalLines: Int
    }

    enum ReadError: LocalizedError {
        case fileTooLarge(Int64, Int64)
        case binaryFile

        var errorDescription: String? {
            switch self {
            case .fileTooLarge(let size, let limit):
                return "File is too large to read without an offset (\(ByteCountFormatter.string(fromByteCount: size, countStyle: .file)); limit \(ByteCountFormatter.string(fromByteCount: limit, countStyle: .file))). Use offset and limit to read a specific range."
            case .binaryFile:
                return "File appears to be binary and is not supported by the text reader."
            }
        }
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
        let selectedLines = Array(allLines[(startLine - 1)..<endLine]).map(boundedLine)
        let formatted = formatLines(selectedLines, startLine: startLine, endLine: endLine, totalLines: totalLines)

        return Result(
            formattedContent: formatted,
            startLine: startLine,
            endLine: endLine,
            totalLines: totalLines
        )
    }

    /// Reads a text file without materializing the whole file in memory.
    ///
    /// Small files use the existing in-memory implementation for speed. Large
    /// files are scanned in fixed-size chunks and only the requested lines are
    /// retained. Negative offsets require a first pass to determine the total
    /// line count, but still never retain the file contents.
    static func read(
        fileURL: URL,
        request: Request,
        maxWholeFileBytes: Int64,
        maxOutputBytes: Int = Self.maxOutputBytes
    ) async throws -> Result {
        try await Task.detached(priority: .utility) {
            try Self.readSynchronously(
                fileURL: fileURL,
                request: request,
                maxWholeFileBytes: maxWholeFileBytes,
                maxOutputBytes: maxOutputBytes
            )
        }.value
    }

    private static func readSynchronously(
        fileURL: URL,
        request: Request,
        maxWholeFileBytes: Int64,
        maxOutputBytes: Int
    ) throws -> Result {
        let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        let fileSize = (attributes[.size] as? NSNumber)?.int64Value ?? 0
        guard fileSize <= maxWholeFileBytes || request.offset != nil else {
            throw ReadError.fileTooLarge(fileSize, maxWholeFileBytes)
        }

        let lineLimit = normalizedLimit(request.limit)
        if fileSize <= Int64(fastPathMaxFileBytes) {
            let data = try Data(contentsOf: fileURL)
            guard !looksBinary(data) else { throw ReadError.binaryFile }
            guard let content = String(data: data, encoding: .utf8) else {
                throw ReadError.binaryFile
            }
            return read(content: content, request: request, maxOutputBytes: maxOutputBytes)
        }

        guard (request.offset ?? 1) >= 0 else {
            let totalLines = try countLines(fileURL: fileURL)
            let startLine = resolveStartLine(offset: request.offset, totalLines: totalLines)
            return try readStream(
                fileURL: fileURL,
                startLine: startLine,
                lineLimit: lineLimit,
                totalLines: totalLines,
                maxOutputBytes: maxOutputBytes
            )
        }

        let startLine = max(1, request.offset ?? 1)
        return try readStream(
            fileURL: fileURL,
            startLine: startLine,
            lineLimit: lineLimit,
            totalLines: nil,
            maxOutputBytes: maxOutputBytes
        )
    }

    private static func read(
        content: String,
        request: Request,
        maxOutputBytes: Int
    ) -> Result {
        let result = read(content: content, request: request)
        guard result.formattedContent.utf8.count > maxOutputBytes else { return result }

        let bytes = Array(result.formattedContent.utf8.prefix(maxOutputBytes))
        let safePrefix = String(decoding: bytes, as: UTF8.self)
        return Result(
            formattedContent: safePrefix + "\n\n[Output truncated at \(maxOutputBytes) bytes.]",
            startLine: result.startLine,
            endLine: result.endLine,
            totalLines: result.totalLines
        )
    }

    private static func countLines(fileURL: URL) throws -> Int {
        try processLines(fileURL: fileURL) { _, _ in }
    }

    private static func readStream(
        fileURL: URL,
        startLine: Int,
        lineLimit: Int,
        totalLines: Int?,
        maxOutputBytes: Int
    ) throws -> Result {
        var selected: [String] = []
        var selectedBytes = 0
        let endExclusive = startLine > Int.max - lineLimit
            ? Int.max
            : startLine + lineLimit
        let countedLines = try processLines(fileURL: fileURL) { lineNumber, line in
            guard lineNumber >= startLine, lineNumber < endExclusive else { return }
            guard selected.count < lineLimit else { return }

            let remaining = maxOutputBytes - selectedBytes - (selected.isEmpty ? 0 : 1)
            guard remaining > 0 else { return }
            let lineData = Data(line.utf8)
            let clippedData = lineData.prefix(min(lineData.count, min(maxLineBytes, remaining)))
            var value = String(decoding: clippedData, as: UTF8.self)
            if clippedData.count < lineData.count {
                value += "…[line truncated]"
            }
            selectedBytes += value.utf8.count + (selected.isEmpty ? 0 : 1)
            selected.append(value)
        }

        let actualTotalLines = totalLines ?? countedLines
        guard actualTotalLines > 0 else {
            return Result(formattedContent: "", startLine: 0, endLine: 0, totalLines: 0)
        }
        let effectiveStartLine = min(startLine, actualTotalLines)
        let endLine = min(effectiveStartLine + selected.count - 1, actualTotalLines)
        let formatted = formatLines(
            selected,
            startLine: effectiveStartLine,
            endLine: endLine,
            totalLines: actualTotalLines
        )
        return Result(
            formattedContent: formatted,
            startLine: effectiveStartLine,
            endLine: endLine,
            totalLines: actualTotalLines
        )
    }

    private static func processLines(
        fileURL: URL,
        handler: (Int, String) -> Void
    ) throws -> Int {
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }

        var lineNumber = 1
        var line = Data()
        var lineWasTruncated = false
        var sawBytes = false
        var firstChunk = true
        while let chunk = try handle.read(upToCount: 256 * 1024), !chunk.isEmpty {
            var bytes = chunk
            sawBytes = true
            if firstChunk {
                firstChunk = false
                if bytes.starts(with: [0xEF, 0xBB, 0xBF]) {
                    bytes = bytes.dropFirst(3)
                }
                guard !looksBinary(bytes) else { throw ReadError.binaryFile }
            }

            for byte in bytes {
                if byte == 0x0A {
                    emitLine(line, lineNumber: lineNumber, truncated: lineWasTruncated, handler: handler)
                    line.removeAll(keepingCapacity: true)
                    lineWasTruncated = false
                    lineNumber += 1
                } else if line.count < maxLineBytes {
                    line.append(byte)
                } else {
                    lineWasTruncated = true
                }
            }
        }

        if sawBytes && (!line.isEmpty || lineNumber == 1 || lineWasTruncated) {
            emitLine(line, lineNumber: lineNumber, truncated: lineWasTruncated, handler: handler)
            return lineNumber
        }
        return sawBytes ? lineNumber - 1 : 0
    }

    private static func emitLine(
        _ data: Data,
        lineNumber: Int,
        truncated: Bool,
        handler: (Int, String) -> Void
    ) {
        var bytes = data
        if bytes.last == 0x0D { bytes.removeLast() }
        var value = String(decoding: bytes, as: UTF8.self)
        if truncated { value += "…[line truncated]" }
        handler(lineNumber, value)
    }

    private static func looksBinary(_ data: Data) -> Bool {
        data.prefix(8192).contains(0)
    }

    private static func boundedLine(_ line: String) -> String {
        let data = Data(line.utf8)
        guard data.count > maxLineBytes else { return line }
        return String(decoding: data.prefix(maxLineBytes), as: UTF8.self) + "…[line truncated]"
    }

    private static func normalizedLimit(_ limit: Int?) -> Int {
        let requested = limit ?? defaultLineLimit
        return min(max(1, requested), maxLineLimit)
    }

    private static func resolveStartLine(offset: Int?, totalLines: Int) -> Int {
        guard let offset else { return 1 }

        if offset < 0 {
            guard totalLines > 0 else { return 0 }
            let distance = min(UInt64(totalLines), UInt64(offset.magnitude))
            return max(1, totalLines - Int(distance) + 1)
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
