import Foundation

/// 行偏移查找表：将 UTF-16 行/字符定位从 O(n)×m 降低到 O(n)+m。
///
/// 对于包含 m 个 token 的大文件，逐个 token 遍历整个字符串的 UTF-16 偏移
/// 会导致 O(m×n) 复杂度（n 为文档长度）。使用此表可降至 O(n)+m。
///
/// 构建一次，后续每次 `utf16Offset(line:character:)` 调用均为 O(1)。
struct LineOffsetTable: Sendable {

    /// 每行起始字符的 UTF-16 偏移量
    private let lineStarts: [Int]

    /// 文档总 UTF-16 长度
    let totalUTF16Length: Int

    /// 从文档内容构建查找表
    init(content: String) {
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

    /// 根据 LSP 行号和字符偏移获取 UTF-16 偏移量（O(1)）
    ///
    /// - Parameters:
    ///   - line: 0-based 行号
    ///   - character: 0-based 字符偏移
    /// - Returns: UTF-16 偏移量，越界时返回 nil
    func utf16Offset(line: Int, character: Int) -> Int? {
        guard line >= 0, line < lineStarts.count, character >= 0 else { return nil }
        let offset = lineStarts[line] + character
        return offset <= totalUTF16Length ? offset : nil
    }

    /// 根据 LSP 行号获取该行起始 UTF-16 偏移量
    func lineStart(line: Int) -> Int? {
        guard line >= 0, line < lineStarts.count else { return nil }
        return lineStarts[line]
    }

    /// 根据 UTF-16 偏移量反查所在行号。
    ///
    /// 对于行尾换行符，仍然认为它属于当前行。
    func lineContaining(utf16Offset: Int) -> Int? {
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

    /// 总行数
    var lineCount: Int { lineStarts.count }

    /// 是否为空文档
    var isEmpty: Bool { lineStarts.isEmpty }
}
