import Foundation

public struct RAGChunker {
    public let maxLines: Int
    public let overlapLines: Int
    public let maxCharsPerChunk: Int

    public init(maxLines: Int = 80, overlapLines: Int = 20, maxCharsPerChunk: Int = 4000) {
        self.maxLines = maxLines
        self.overlapLines = overlapLines
        self.maxCharsPerChunk = maxCharsPerChunk
    }

    public func chunk(_ content: String) -> [RAGChunk] {
        let lines = content.components(separatedBy: .newlines)
        guard !lines.isEmpty else { return [] }

        var chunks: [RAGChunk] = []
        var start = 0
        var chunkIndex = 0

        while start < lines.count {
            let end = min(start + maxLines, lines.count)
            let block = lines[start..<end].joined(separator: "\n")

            if block.count <= maxCharsPerChunk {
                let trimmed = block.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    chunks.append(
                        RAGChunk(
                            index: chunkIndex,
                            content: trimmed,
                            lineRange: RAGLineRange(startLine: start + 1, endLine: end)
                        )
                    )
                    chunkIndex += 1
                }
            } else {
                // 单块过大时，按字符窗口再切
                var cursor = block.startIndex
                while cursor < block.endIndex {
                    let next = block.index(cursor, offsetBy: maxCharsPerChunk, limitedBy: block.endIndex) ?? block.endIndex
                    let segment = String(block[cursor..<next]).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !segment.isEmpty {
                        let startLine = start + 1 + block[..<cursor].reduce(into: 0) { count, character in
                            if character == "\n" { count += 1 }
                        }
                        let endLine = startLine + segment.reduce(into: 0) { count, character in
                            if character == "\n" { count += 1 }
                        }
                        chunks.append(
                            RAGChunk(
                                index: chunkIndex,
                                content: segment,
                                lineRange: RAGLineRange(startLine: startLine, endLine: endLine)
                            )
                        )
                        chunkIndex += 1
                    }
                    cursor = next
                }
            }

            if end == lines.count { break }
            start = max(end - overlapLines, start + 1)
        }

        return chunks
    }
}
