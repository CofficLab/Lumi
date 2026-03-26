import Foundation

struct RAGChunker {
    let maxLines: Int
    let overlapLines: Int
    let maxCharsPerChunk: Int

    init(maxLines: Int = 80, overlapLines: Int = 20, maxCharsPerChunk: Int = 4000) {
        self.maxLines = maxLines
        self.overlapLines = overlapLines
        self.maxCharsPerChunk = maxCharsPerChunk
    }

    func chunk(_ content: String) -> [RAGChunk] {
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
                    chunks.append(RAGChunk(index: chunkIndex, content: trimmed))
                    chunkIndex += 1
                }
            } else {
                // 单块过大时，按字符窗口再切
                var cursor = block.startIndex
                while cursor < block.endIndex {
                    let next = block.index(cursor, offsetBy: maxCharsPerChunk, limitedBy: block.endIndex) ?? block.endIndex
                    let segment = String(block[cursor..<next]).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !segment.isEmpty {
                        chunks.append(RAGChunk(index: chunkIndex, content: segment))
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

