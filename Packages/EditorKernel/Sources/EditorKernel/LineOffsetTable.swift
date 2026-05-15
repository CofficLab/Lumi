import Foundation

public struct LineOffsetTable: Sendable {
    private let lineStarts: [Int]
    public let totalUTF16Length: Int

    public init(content: String) {
        var starts = [Int]()
        starts.reserveCapacity(content.filter { $0 == "\n" }.count + 1)
        starts.append(0)
        var offset = 0
        for scalar in content.unicodeScalars {
            offset += scalar.utf16.count
            if scalar == "\n" {
                starts.append(offset)
            }
        }
        self.lineStarts = starts
        self.totalUTF16Length = content.utf16.count
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
}
