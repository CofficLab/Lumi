import Foundation

public struct LineOffsetTable: Sendable {
    private let lineStarts: [Int]
    public let totalUTF16Length: Int

    public init(content: String) {
        var starts = [Int]()
        // Optimized: Single pass to count newlines and build line starts
        starts.append(0)
        var offset = 0
        for scalar in content.unicodeScalars {
            offset += scalar.utf16.count
            if scalar == "\n" {
                starts.append(offset)
            }
        }
        self.lineStarts = starts
        self.totalUTF16Length = offset
    }
    
    /// Internal initializer for incremental updates
    private init(lineStarts: [Int], totalUTF16Length: Int) {
        self.lineStarts = lineStarts
        self.totalUTF16Length = totalUTF16Length
    }

    public func utf16Offset(line: Int, character: Int) -> Int? {
        guard line >= 0, line < lineStarts.count, character >= 0 else { return nil }
        let offset = lineStarts[line] + character
        return offset <= totalUTF16Length ? offset : nil
    }

    public func lineStart(line: Int) -> Int? {
        guard line >= 0, line < lineStarts.count else { return nil }
        return lineStarts[line]
    }

    public func lineContaining(utf16Offset: Int) -> Int? {
        guard utf16Offset >= 0, utf16Offset <= totalUTF16Length, !lineStarts.isEmpty else {
            return nil
        }

        var low = 0
        var high = lineStarts.count - 1

        while low <= high {
            let mid = (low + high) / 2
            let start = lineStarts[mid]
            let nextStart = mid + 1 < lineStarts.count ? lineStarts[mid + 1] : totalUTF16Length + 1

            if utf16Offset < start {
                high = mid - 1
            } else if utf16Offset >= nextStart {
                low = mid + 1
            } else {
                return mid
            }
        }

        return max(0, min(high, lineStarts.count - 1))
    }

    public var lineCount: Int { lineStarts.count }
    public var isEmpty: Bool { lineStarts.isEmpty }
    
    /// Incremental update for edit operations
    /// - Parameters:
    ///   - editRange: The range that was edited (in UTF-16 offsets)
    ///   - changeInLength: The change in length (positive for insertions, negative for deletions)
    ///   - newContent: The new content that was inserted (if any)
    /// - Returns: A new LineOffsetTable with the updates applied
    public func update(editRange: NSRange, changeInLength: Int, newContent: String? = nil) -> LineOffsetTable {
        guard editRange.location >= 0,
              editRange.length >= 0,
              editRange.location <= totalUTF16Length,
              editRange.location <= Int.max - editRange.length else {
            return self
        }

        let editEndLocation = editRange.location + editRange.length
        guard editEndLocation <= totalUTF16Length else {
            return self
        }

        let (updatedTotalLength, totalLengthOverflow) = totalUTF16Length.addingReportingOverflow(changeInLength)
        guard !totalLengthOverflow, updatedTotalLength >= 0 else {
            return self
        }

        // Find the line containing the edit start
        guard let startLine = lineContaining(utf16Offset: editRange.location) else {
            return self
        }
        
        // Find the line containing the edit end
        let endLine = lineContaining(utf16Offset: editEndLocation) ?? startLine
        
        // Calculate new line starts
        var newLineStarts = lineStarts
        
        // 1. Remove lines that were completely deleted
        if changeInLength < 0 && endLine > startLine {
            // Lines were deleted
            newLineStarts.removeSubrange((startLine + 1)...endLine)
        }
        
        // 2. Update offsets for lines after the edit
        let delta = changeInLength
        if delta != 0 {
            for i in (startLine + 1)..<newLineStarts.count {
                newLineStarts[i] += delta
            }
        }
        
        // 3. Handle new lines in inserted content
        if let newContent = newContent, newContent.contains("\n") {
            // Count new lines in inserted content
            var newLineOffsets: [Int] = []
            var contentOffset = 0
            for scalar in newContent.unicodeScalars {
                if scalar == "\n" {
                    newLineOffsets.append(contentOffset + 1)
                }
                contentOffset += scalar.utf16.count
            }
            
            // Insert new line starts at the correct position
            let insertPosition = startLine + 1
            for (index, lineOffset) in newLineOffsets.enumerated() {
                let absoluteOffset = editRange.location + lineOffset
                newLineStarts.insert(absoluteOffset, at: insertPosition + index)
            }
        }
        
        return LineOffsetTable(
            lineStarts: newLineStarts,
            totalUTF16Length: updatedTotalLength
        )
    }
}
