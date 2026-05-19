import Foundation

public extension LumiPreviewFacade {
    /// 源码扫描器：从 Swift 源码中检测 `#Preview` 宏并提取信息。
    ///
    /// 核心能力：
    /// - 建立 code mask，跳过注释和字符串中的误匹配
    /// - 花括号平衡匹配，准确提取闭包范围
    /// - 提取标题、行号范围、主视图类型名、闭包 body 源码
    final class PreviewScanner: Sendable {
        /// 创建源码扫描器。
        public init() {}

        // MARK: - 公开方法

        /// 扫描指定源码文件中的 `#Preview` 宏。
        ///
        /// - Parameters:
        ///   - fileURL: 源文件的 URL（仅用于记录在 `PreviewDiscovery.sourceFileURL` 中）。
        ///   - sourceText: 源文件的完整文本。
        /// - Returns: 检测到的所有 `PreviewDiscovery`。
        public func scan(fileURL: URL, sourceText: String) -> [PreviewDiscovery] {
            guard sourceText.contains("#Preview") else { return [] }

            let source = _Source(sourceText)
            var previews: [PreviewDiscovery] = []
            let previewOffsets = source.codeOffsets(matching: "#Preview")

            for previewOffset in previewOffsets {
                guard let openingBraceOffset = source.firstCodeOffset(of: "{", after: previewOffset),
                      let body = source.balancedBody(openingBraceOffset: openingBraceOffset) else {
                    continue
                }

                let signature = source.string(from: previewOffset, to: openingBraceOffset)
                let lineNumber = source.lineNumber(at: previewOffset)
                let title = Self.title(in: signature)
                    ?? String(format: "Preview %d", previews.count + 1)

                previews.append(
                    PreviewDiscovery(
                        id: "source-preview-\(lineNumber)-\(previews.count)",
                        title: title,
                        sourceFileURL: fileURL,
                        lineNumber: lineNumber,
                        endLineNumber: source.lineNumber(at: body.closingBraceOffset),
                        primaryTypeName: Self.primaryTypeName(in: body.source),
                        bodySource: body.source,
                        layout: Self.layout(in: signature),
                        sourceText: sourceText
                    )
                )
            }

            return previews
        }

        // MARK: - 私有方法

        /// 从 `#Preview` 签名中提取标题字符串。
        ///
        /// 支持格式：`#Preview("Title")`、`#Preview("Multi\nLine")`。
        private static func title(in signature: String) -> String? {
            guard let firstQuote = signature.firstIndex(of: "\"") else { return nil }

            var result = ""
            var index = signature.index(after: firstQuote)
            var isEscaped = false

            while index < signature.endIndex {
                let character = signature[index]
                if isEscaped {
                    result.append(character)
                    isEscaped = false
                } else if character == "\\" {
                    isEscaped = true
                } else if character == "\"" {
                    return result.isEmpty ? nil : result
                } else {
                    result.append(character)
                }
                index = signature.index(after: index)
            }

            return nil
        }

        /// 从 `#Preview` 签名中提取 Xcode-style layout traits。
        ///
        /// 当前支持：
        /// - `traits: .sizeThatFitsLayout`
        /// - `traits: .fixedLayout(width: 320, height: 480)`，仅解析数字字面量。
        private static func layout(in signature: String) -> PreviewDiscovery.Layout {
            if signature.contains(".sizeThatFitsLayout") {
                return .sizeThatFits
            }

            guard signature.contains(".fixedLayout") else {
                return .automatic
            }

            let pattern = #"\.fixedLayout\s*\(\s*width\s*:\s*([0-9]+(?:\.[0-9]+)?)\s*,\s*height\s*:\s*([0-9]+(?:\.[0-9]+)?)\s*\)"#
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(
                      in: signature,
                      range: NSRange(signature.startIndex..<signature.endIndex, in: signature)
                  ),
                  match.numberOfRanges == 3,
                  let widthRange = Range(match.range(at: 1), in: signature),
                  let heightRange = Range(match.range(at: 2), in: signature),
                  let width = Double(signature[widthRange]),
                  let height = Double(signature[heightRange]) else {
                return .automatic
            }

            return .fixed(width: width, height: height)
        }

        /// 从闭包 body 源码中提取主视图类型名。
        ///
        /// 提取第一个以字母或下划线开头的连续标识符作为类型名。
        private static func primaryTypeName(in bodySource: String?) -> String? {
            guard let bodySource else { return nil }
            let trimmed = bodySource.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let firstScalar = trimmed.unicodeScalars.first,
                  CharacterSet.letters.contains(firstScalar) || firstScalar == UnicodeScalar("_") else {
                return nil
            }

            var result = ""
            for scalar in trimmed.unicodeScalars {
                if CharacterSet.alphanumerics.contains(scalar) || scalar == UnicodeScalar("_") {
                    result.append(String(scalar))
                } else {
                    break
                }
            }

            return result.isEmpty ? nil : result
        }
    }

    // MARK: - 内部源码分析工具

    /// 源码文本分析器，提供 code mask、偏移定位、花括号平衡等能力。
    private struct _Source {
        private let text: String
        private let characters: [Character]
        private let isCode: [Bool]
        private let lineStartOffsets: [Int]

        init(_ text: String) {
            self.text = text
            self.characters = Array(text)
            self.isCode = Self.makeCodeMask(characters: self.characters)
            self.lineStartOffsets = Self.makeLineStartOffsets(characters: self.characters)
        }

        /// 在代码区查找所有匹配 `needle` 的偏移量。
        ///
        /// 同时确保匹配位置是一个宏边界（前后不是标识符字符）。
        func codeOffsets(matching needle: String) -> [Int] {
            let needleCharacters = Array(needle)
            guard !needleCharacters.isEmpty, characters.count >= needleCharacters.count else { return [] }

            var offsets: [Int] = []
            for offset in 0 ... (characters.count - needleCharacters.count) {
                guard isCode[offset],
                      matches(needleCharacters, at: offset),
                      isMacroBoundary(before: offset, length: needleCharacters.count) else {
                    continue
                }
                offsets.append(offset)
            }
            return offsets
        }

        /// 在代码区从指定偏移后查找第一个目标字符。
        func firstCodeOffset(of character: Character, after offset: Int) -> Int? {
            guard offset < characters.count else { return nil }
            for index in offset ..< characters.count where isCode[index] && characters[index] == character {
                return index
            }
            return nil
        }

        /// 从开括号 `{` 位置开始，进行花括号平衡匹配，返回闭包体和闭括号偏移。
        func balancedBody(openingBraceOffset: Int) -> (source: String?, closingBraceOffset: Int)? {
            guard openingBraceOffset < characters.count, characters[openingBraceOffset] == "{" else { return nil }

            var depth = 0
            for offset in openingBraceOffset ..< characters.count where isCode[offset] {
                if characters[offset] == "{" {
                    depth += 1
                } else if characters[offset] == "}" {
                    depth -= 1
                    if depth == 0 {
                        return (
                            source: string(from: openingBraceOffset + 1, to: offset),
                            closingBraceOffset: offset
                        )
                    }
                }
            }

            return nil
        }

        /// 返回指定偏移量所在的行号（从 1 开始）。
        func lineNumber(at offset: Int) -> Int {
            guard !lineStartOffsets.isEmpty else { return 1 }
            var low = 0
            var high = lineStartOffsets.count

            while low < high {
                let mid = (low + high) / 2
                if lineStartOffsets[mid] <= offset {
                    low = mid + 1
                } else {
                    high = mid
                }
            }

            return max(1, low)
        }

        /// 提取指定偏移范围内的子字符串。
        func string(from startOffset: Int, to endOffset: Int) -> String {
            guard startOffset < endOffset,
                  startOffset >= 0,
                  endOffset <= characters.count else {
                return ""
            }
            return String(characters[startOffset ..< endOffset])
        }

        // MARK: - 私有方法

        private func matches(_ needleCharacters: [Character], at offset: Int) -> Bool {
            for needleIndex in needleCharacters.indices where characters[offset + needleIndex] != needleCharacters[needleIndex] {
                return false
            }
            return true
        }

        /// 检查匹配位置前后是否为宏边界（不是标识符字符的一部分）。
        private func isMacroBoundary(before offset: Int, length: Int) -> Bool {
            let previous = offset > 0 ? characters[offset - 1] : nil
            let nextOffset = offset + length
            let next = nextOffset < characters.count ? characters[nextOffset] : nil
            return !Self.isIdentifierCharacter(previous) && !Self.isIdentifierCharacter(next)
        }

        private static func isIdentifierCharacter(_ character: Character?) -> Bool {
            guard let scalar = character?.unicodeScalars.first else { return false }
            return CharacterSet.alphanumerics.contains(scalar) || scalar == UnicodeScalar("_")
        }

        /// 构建行起始偏移量表，用于快速行号查询。
        private static func makeLineStartOffsets(characters: [Character]) -> [Int] {
            var offsets = [0]
            for (offset, character) in characters.enumerated() where character == "\n" {
                offsets.append(offset + 1)
            }
            return offsets
        }

        /// 构建 code mask：标记哪些字符是真正的代码（排除注释和字符串）。
        ///
        /// 处理的内容：
        /// - 单行注释 `// ...`
        /// - 多行注释 `/* ... */`
        /// - 多行字符串字面量 `""" ... """`
        /// - 普通字符串 `"..."`（处理转义字符）
        private static func makeCodeMask(characters: [Character]) -> [Bool] {
            var mask = Array(repeating: true, count: characters.count)
            var offset = 0

            while offset < characters.count {
                if characters[offset] == "/", characters[safe: offset + 1] == "/" {
                    // 单行注释
                    let start = offset
                    offset += 2
                    while offset < characters.count, characters[offset] != "\n" {
                        offset += 1
                    }
                    markNonCode(in: start ..< offset, mask: &mask)
                } else if characters[offset] == "/", characters[safe: offset + 1] == "*" {
                    // 多行注释
                    let start = offset
                    offset += 2
                    while offset < characters.count {
                        if characters[offset] == "*", characters[safe: offset + 1] == "/" {
                            offset += 2
                            break
                        }
                        offset += 1
                    }
                    markNonCode(in: start ..< min(offset, characters.count), mask: &mask)
                } else if isTripleQuote(at: offset, characters: characters) {
                    // 多行字符串字面量
                    let start = offset
                    offset += 3
                    while offset < characters.count {
                        if isTripleQuote(at: offset, characters: characters) {
                            offset += 3
                            break
                        }
                        offset += 1
                    }
                    markNonCode(in: start ..< min(offset, characters.count), mask: &mask)
                } else if characters[offset] == "\"" {
                    // 普通字符串
                    let start = offset
                    offset += 1
                    var isEscaped = false
                    while offset < characters.count {
                        let character = characters[offset]
                        if isEscaped {
                            isEscaped = false
                        } else if character == "\\" {
                            isEscaped = true
                        } else if character == "\"" {
                            offset += 1
                            break
                        }
                        offset += 1
                    }
                    markNonCode(in: start ..< min(offset, characters.count), mask: &mask)
                } else {
                    offset += 1
                }
            }

            return mask
        }

        private static func isTripleQuote(at offset: Int, characters: [Character]) -> Bool {
            characters[safe: offset] == "\""
                && characters[safe: offset + 1] == "\""
                && characters[safe: offset + 2] == "\""
        }

        private static func markNonCode(in range: Range<Int>, mask: inout [Bool]) {
            for offset in range where offset < mask.count {
                mask[offset] = false
            }
        }
    }

    // MARK: - 安全下标
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
