import Foundation

public struct RAGChunker: Sendable {
    public let maxLines: Int
    public let overlapLines: Int
    public let maxCharsPerChunk: Int

    public init(maxLines: Int = 80, overlapLines: Int = 20, maxCharsPerChunk: Int = 4000) {
        self.maxLines = maxLines
        self.overlapLines = overlapLines
        self.maxCharsPerChunk = maxCharsPerChunk
    }

    public func chunk(_ content: String) -> [RAGChunk] {
        // 按 Character 拆分：`\r\n` 在 Swift 中是单个字符，必须整体算一个换行，
        // 否则 CRLF 文件每两行之间会多出一个空行、窗口和行号翻倍（回归 #1114）。
        // 保留空子序列，显式空行仍然占用真实行号。
        let lines = content.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
        guard !lines.isEmpty else { return [] }

        var chunks: [RAGChunk] = []
        var start = 0
        var chunkIndex = 0

        while start < lines.count {
            var end = min(start + maxLines, lines.count)
            if end < lines.count {
                end = preferredCut(start: start, end: end, lines: lines)
            }
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

    /// 窗口内选切点：空行 > 顶层声明起始行 > 窗口末端（保持旧行为）。
    /// 从窗口末端向前找，取最靠后的边界，让当前块尽量装满。
    private func preferredCut(start: Int, end: Int, lines: [Substring]) -> Int {
        var declarationCut: Int?
        var index = end - 1
        while index > start {
            let line = lines[index]
            if line.allSatisfy(\.isWhitespace) {
                return index
            }
            if declarationCut == nil, Self.isDeclarationStart(line) {
                declarationCut = index
            }
            index -= 1
        }
        return declarationCut ?? end
    }

    /// 行首无缩进的声明起始（Swift/JS/TS/Python 启发式，不引入 tree-sitter）。
    private static func isDeclarationStart(_ line: Substring) -> Bool {
        guard let first = line.first, !first.isWhitespace else { return false }
        let keywords: Set<String> = [
            "func", "function", "class", "struct", "enum", "protocol",
            "extension", "import", "def", "const", "let", "var",
        ]
        let modifiers: Set<String> = [
            "public", "private", "internal", "fileprivate", "open", "final",
            "static", "override", "export", "default", "abstract", "async",
        ]
        for word in line.split(whereSeparator: \.isWhitespace) {
            let token = String(word)
            if keywords.contains(token) { return true }
            if !modifiers.contains(token) { return false }
        }
        return false
    }
}
