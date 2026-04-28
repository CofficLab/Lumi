import Foundation

// MARK: - Line Editing Commands
//
// Phase 9: 编辑体验打磨 — 行编辑命令。
//
// VS Code 风格的行编辑命令是高频日常编码操作，包括：
// 1. 删除当前行 (delete line)
// 2. 复制当前行向上/向下 (copy line up / copy line down)
// 3. 移动当前行向上/向下 (move line up / move line down)
// 4. 在下方插入新行 (insert line below)
// 5. 在上方插入新行 (insert line above)
// 6. 行排序 (sort lines ascending / descending)
// 7. 删除行尾空白 (trim trailing whitespace — 已在 save pipeline 中实现)
// 8. 转置行 (transpose lines)

/// 行编辑命令结果
struct LineEditResult: Equatable, Sendable {
    /// 替换范围（NSRange，覆盖整个受影响区域）
    let replacementRange: NSRange
    /// 替换文本
    let replacementText: String
    /// 编辑后的光标选区（NSRange 数组）
    let selectedRanges: [NSRange]
}

/// 行编辑命令引擎
///
/// 所有行编辑命令都接受当前文本 + 选区信息，
/// 返回替换范围 + 替换文本 + 新选区。
/// 不直接操作任何 UI 或状态对象。
enum LineEditingController: Sendable {

    // MARK: - Delete Line

    /// 删除光标/选区所在的所有行
    ///
    /// 行为：
    /// - 无选区：删除光标所在行
    /// - 有选区：删除选区跨越的所有行
    /// - 删除最后一行后，光标移到上一行末尾
    /// - 多光标：每条光标独立删除各自所在行
    static func deleteLine(
        in text: String,
        selections: [NSRange]
    ) -> LineEditResult? {
        let nsText = text as NSString
        guard !selections.isEmpty else { return nil }

        let lineRanges = selections.map { selection in
            fullLineRange(for: selection, in: nsText)
        }

        let mergedRanges = mergeOverlappingRanges(lineRanges)

        // 检查是否删除到文件末尾
        let totalLength = nsText.length
        let lastRange = mergedRanges.last!
        let isDeletingToEnd = NSMaxRange(lastRange) >= totalLength

        var replacements: [(range: NSRange, text: String)] = []
        for (index, range) in mergedRanges.enumerated() {
            // 如果是最后一个删除范围且删除到文件末尾
            // 需要同时删除前一个换行符
            if index == mergedRanges.count - 1 && isDeletingToEnd {
                let adjustedLocation = max(0, range.location - 1)
                let adjustedRange = NSRange(
                    location: adjustedLocation,
                    length: totalLength - adjustedLocation
                )
                replacements.append((adjustedRange, ""))
            } else {
                replacements.append((range, ""))
            }
        }

        return applyLineEdits(
            text: text,
            replacements: replacements,
            originalSelections: selections,
            cursorBehavior: .lineStart
        )
    }

    // MARK: - Copy Line Up / Down

    /// 复制当前行向上
    static func copyLineUp(
        in text: String,
        selections: [NSRange]
    ) -> LineEditResult? {
        copyLine(in: text, selections: selections, direction: .up)
    }

    /// 复制当前行向下
    static func copyLineDown(
        in text: String,
        selections: [NSRange]
    ) -> LineEditResult? {
        copyLine(in: text, selections: selections, direction: .down)
    }

    // MARK: - Move Line Up / Down

    /// 移动当前行向上
    static func moveLineUp(
        in text: String,
        selections: [NSRange]
    ) -> LineEditResult? {
        moveLine(in: text, selections: selections, direction: .up)
    }

    /// 移动当前行向下
    static func moveLineDown(
        in text: String,
        selections: [NSRange]
    ) -> LineEditResult? {
        moveLine(in: text, selections: selections, direction: .down)
    }

    // MARK: - Insert Line Above / Below

    /// 在当前行下方插入新行，光标定位到新行
    static func insertLineBelow(
        in text: String,
        selections: [NSRange]
    ) -> LineEditResult? {
        let nsText = text as NSString
        guard !selections.isEmpty else { return nil }

        // 对每个选区，在所在行末尾插入换行 + 保持缩进
        var edits: [(range: NSRange, text: String)] = []
        var newCursors: [NSRange] = []

        for selection in selections {
            let lineRange = nsText.lineRange(for: selection)
            let lineText = nsText.substring(with: lineRange)
            let lineContent = lineText.hasSuffix("\n")
                ? String(lineText.dropLast())
                : lineText

            // 提取当前行的前导空白
            let indent = String(lineContent.prefix(while: { $0 == " " || $0 == "\t" }))

            let insertLocation = NSMaxRange(lineRange) - (lineText.hasSuffix("\n") ? 1 : 0)
            let newText = "\n" + indent
            edits.append((
                range: NSRange(location: insertLocation, length: 0),
                text: newText
            ))
            newCursors.append(NSRange(
                location: insertLocation + newText.count,
                length: 0
            ))
        }

        // 从后向前应用编辑以避免偏移
        return applyEditsFromBack(
            text: text,
            edits: edits,
            newCursors: newCursors
        )
    }

    /// 在当前行上方插入新行，光标定位到新行
    static func insertLineAbove(
        in text: String,
        selections: [NSRange]
    ) -> LineEditResult? {
        let nsText = text as NSString
        guard !selections.isEmpty else { return nil }

        var edits: [(range: NSRange, text: String)] = []
        var newCursors: [NSRange] = []

        for selection in selections {
            let lineRange = nsText.lineRange(for: selection)
            let lineText = nsText.substring(with: NSRange(
                location: lineRange.location,
                length: min(lineRange.length, nsText.length - lineRange.location)
            ))
            let lineContent = lineText.hasSuffix("\n")
                ? String(lineText.dropLast())
                : lineText

            let indent = String(lineContent.prefix(while: { $0 == " " || $0 == "\t" }))

            let insertLocation = lineRange.location
            let newText = indent + "\n"
            edits.append((
                range: NSRange(location: insertLocation, length: 0),
                text: newText
            ))
            newCursors.append(NSRange(
                location: insertLocation + indent.count,
                length: 0
            ))
        }

        return applyEditsFromBack(
            text: text,
            edits: edits,
            newCursors: newCursors
        )
    }

    // MARK: - Sort Lines

    /// 对选区内的行进行排序
    static func sortLines(
        in text: String,
        selections: [NSRange],
        descending: Bool
    ) -> LineEditResult? {
        let nsText = text as NSString
        guard let selection = selections.first, selection.length > 0 else { return nil }

        let lineRange = nsText.lineRange(for: selection)
        let selectedText = nsText.substring(with: lineRange)

        // 分割行（保留末尾换行符）
        var lines = selectedText.components(separatedBy: "\n")
        // 最后一行如果是空字符串（因为末尾换行），先分离出来
        let hasTrailingNewline = selectedText.hasSuffix("\n")
        if hasTrailingNewline && lines.last == "" {
            lines.removeLast()
        }

        guard lines.count > 1 else { return nil }

        if descending {
            lines.sort { $0.localizedCaseInsensitiveCompare($1) == .orderedDescending }
        } else {
            lines.sort { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        }

        let sortedText = lines.joined(separator: "\n") + (hasTrailingNewline ? "\n" : "")

        let newSelectionLength = (sortedText as NSString).length

        return LineEditResult(
            replacementRange: lineRange,
            replacementText: sortedText,
            selectedRanges: [NSRange(location: lineRange.location, length: newSelectionLength)]
        )
    }

    // MARK: - Transpose

    /// 转置光标两侧的字符，如果光标在行首/行尾则转置相邻行
    static func transpose(
        in text: String,
        selections: [NSRange]
    ) -> LineEditResult? {
        let nsText = text as NSString
        guard let selection = selections.first,
              selection.length == 0,
              selection.location > 0,
              selection.location < nsText.length else { return nil }

        let location = selection.location

        // 如果光标前和光标后都有字符，交换两个字符
        let before = nsText.substring(with: NSRange(location: location - 1, length: 1))
        let after = nsText.substring(with: NSRange(location: location, length: 1))

        if before != "\n" && after != "\n" {
            let swapped = after + before
            return LineEditResult(
                replacementRange: NSRange(location: location - 1, length: 2),
                replacementText: swapped,
                selectedRanges: [NSRange(location: location + 1, length: 0)]
            )
        }

        return nil
    }

    // MARK: - Toggle Line Comment

    /// 切换行注释
    ///
    /// - 如果所有选区行都已注释，则取消注释
    /// - 否则添加注释
    static func toggleLineComment(
        in text: String,
        selections: [NSRange],
        commentPrefix: String
    ) -> LineEditResult? {
        let nsText = text as NSString
        guard !selections.isEmpty else { return nil }

        let prefix = commentPrefix
        let prefixLength = (prefix as NSString).length

        // 收集所有受影响行
        var allLineStarts: Set<Int> = []
        for selection in selections {
            let lineRange = nsText.lineRange(for: selection)
            var pos = lineRange.location
            while pos < NSMaxRange(lineRange) && pos < nsText.length {
                allLineStarts.insert(pos)
                let currentLineRange = nsText.lineRange(for: NSRange(location: pos, length: 0))
                pos = NSMaxRange(currentLineRange)
                if pos <= currentLineRange.location { break }
            }
        }

        let sortedLineStarts = allLineStarts.sorted()

        // 检查是否所有行都已注释
        let allCommented = sortedLineStarts.allSatisfy { lineStart in
            guard lineStart + prefixLength <= nsText.length else { return false }
            let linePrefix = nsText.substring(with: NSRange(location: lineStart, length: prefixLength))
            // 跳过空白前缀检查
            if linePrefix.trimmingCharacters(in: .whitespaces).isEmpty { return true }
            return linePrefix.hasPrefix(prefix)
        }

        var replacements: [(range: NSRange, text: String)] = []
        for lineStart in sortedLineStarts {
            let lineRange = nsText.lineRange(for: NSRange(location: lineStart, length: 0))
            let lineEnd = min(NSMaxRange(lineRange), nsText.length)
            var lineText = nsText.substring(with: NSRange(location: lineStart, length: lineEnd - lineStart))

            if allCommented {
                // 取消注释
                if lineText.hasPrefix(prefix + " ") {
                    lineText = String(lineText.dropFirst(prefixLength + 1))
                } else if lineText.hasPrefix(prefix) {
                    lineText = String(lineText.dropFirst(prefixLength))
                }
            } else {
                // 添加注释
                if !lineText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    lineText = prefix + " " + lineText
                }
            }

            replacements.append((
                range: NSRange(location: lineStart, length: lineEnd - lineStart),
                text: lineText
            ))
        }

        return applyLineEdits(
            text: text,
            replacements: replacements,
            originalSelections: selections,
            cursorBehavior: .preserve
        )
    }

    // MARK: - Private

    private enum CopyDirection {
        case up, down
    }

    private enum MoveDirection {
        case up, down
    }

    private enum CursorBehavior {
        case lineStart
        case preserve
    }

    private static func copyLine(
        in text: String,
        selections: [NSRange],
        direction: CopyDirection
    ) -> LineEditResult? {
        let nsText = text as NSString
        guard !selections.isEmpty else { return nil }

        let lineRanges = selections.map { selection in
            fullLineRange(for: selection, in: nsText)
        }

        let mergedRanges = mergeOverlappingRanges(lineRanges)

        // 收集所有要复制的行文本
        var copiedTexts: [String] = []
        for range in mergedRanges {
            let lineText = nsText.substring(with: range)
            copiedTexts.append(lineText)
        }

        var edits: [(range: NSRange, text: String)] = []
        var newCursors: [NSRange] = []

        for (index, range) in mergedRanges.enumerated() {
            let lineText = copiedTexts[index]
            // 复制的内容需要确保以换行结尾
            let insertText: String
            if lineText.hasSuffix("\n") {
                insertText = lineText
            } else {
                insertText = lineText + "\n"
            }

            let insertLocation: Int
            switch direction {
            case .up:
                insertLocation = range.location
            case .down:
                insertLocation = NSMaxRange(range)
                // 如果是最后一行且没有末尾换行，需要在新行前加换行
                if !lineText.hasSuffix("\n") {
                    // insertText 已经加了换行
                }
            }

            edits.append((
                range: NSRange(location: insertLocation, length: 0),
                text: insertText
            ))

            // 光标放到复制的新行上（保持与原光标相同的列位置）
            let originalSelection = selections[index]
            let originalColumn = originalSelection.location - range.location
            let lineContentLength = (lineText as NSString).length - (lineText.hasSuffix("\n") ? 1 : 0)

            let cursorLocation: Int
            switch direction {
            case .up:
                cursorLocation = insertLocation + min(originalColumn, max(lineContentLength, 0))
            case .down:
                cursorLocation = insertLocation + min(originalColumn, max(lineContentLength, 0))
            }

            newCursors.append(NSRange(location: cursorLocation, length: 0))
        }

        return applyEditsFromBack(
            text: text,
            edits: edits,
            newCursors: newCursors
        )
    }

    private static func moveLine(
        in text: String,
        selections: [NSRange],
        direction: MoveDirection
    ) -> LineEditResult? {
        let nsText = text as NSString
        guard !selections.isEmpty else { return nil }

        let lineRanges = selections.map { selection in
            fullLineRange(for: selection, in: nsText)
        }
        let mergedRanges = mergeOverlappingRanges(lineRanges)

        switch direction {
        case .up:
            // 检查是否可以向上移动（第一行不能上移）
            guard let firstRange = mergedRanges.first,
                  firstRange.location > 0 else { return nil }

            // 获取移动块上方的行
            let aboveLineRange = nsText.lineRange(for: NSRange(
                location: firstRange.location - 1, length: 0
            ))

            // 交换：上方行移到下方，移动块移到上方
            let swapRange = NSRange(
                location: aboveLineRange.location,
                length: NSMaxRange(mergedRanges.last!) - aboveLineRange.location
            )

            let aboveText = nsText.substring(with: aboveLineRange)
            let blockText = mergedRanges.map { nsText.substring(with: $0) }.joined()

            let newText = blockText + aboveText
            let shift = (newText as NSString).length - (swapRange.length as Int)

            // 计算新光标位置
            let newCursors = selections.map { selection in
                let offset = selection.location - aboveLineRange.location
                // 块移到上方，光标跟着块移动
                let newLocation = swapRange.location + min(offset, max((newText as NSString).length - 1, 0))
                return NSRange(location: newLocation, length: selection.length)
            }

            return LineEditResult(
                replacementRange: swapRange,
                replacementText: newText,
                selectedRanges: newCursors
            )

        case .down:
            // 检查是否可以向下移动（最后一行不能下移）
            guard let lastRange = mergedRanges.last,
                  NSMaxRange(lastRange) < nsText.length else { return nil }

            // 获取移动块下方的行
            let belowLineStart = NSMaxRange(lastRange)
            let belowLineRange = nsText.lineRange(for: NSRange(
                location: belowLineStart, length: 0
            ))

            // 交换：移动块移到下方行的下面
            let swapRange = NSRange(
                location: mergedRanges.first!.location,
                length: NSMaxRange(belowLineRange) - mergedRanges.first!.location
            )

            let blockText = mergedRanges.map { nsText.substring(with: $0) }.joined()
            let belowText = nsText.substring(with: belowLineRange)

            let newText = belowText + blockText

            // 计算新光标位置：块向下移动了一行
            let blockSize = (blockText as NSString).length
            let belowSize = (belowText as NSString).length

            let newCursors = selections.map { selection in
                let offset = selection.location - mergedRanges.first!.location
                let newLocation = swapRange.location + belowSize + min(offset, max(blockSize - 1, 0))
                return NSRange(location: newLocation, length: selection.length)
            }

            return LineEditResult(
                replacementRange: swapRange,
                replacementText: newText,
                selectedRanges: newCursors
            )
        }
    }

    // MARK: - Helpers

    /// 获取选区覆盖的完整行范围（包括换行符）
    static func fullLineRange(for selection: NSRange, in nsText: NSString) -> NSRange {
        let lineRange = nsText.lineRange(for: selection)
        return lineRange
    }

    /// 合并重叠或相邻的 NSRange
    static func mergeOverlappingRanges(_ ranges: [NSRange]) -> [NSRange] {
        guard !ranges.isEmpty else { return [] }
        let sorted = ranges.sorted { $0.location < $1.location }

        var merged: [NSRange] = [sorted[0]]
        for range in sorted.dropFirst() {
            let last = merged.last!
            if range.location <= NSMaxRange(last) {
                let newEnd = max(NSMaxRange(last), NSMaxRange(range))
                merged[merged.count - 1] = NSRange(
                    location: last.location,
                    length: newEnd - last.location
                )
            } else {
                merged.append(range)
            }
        }
        return merged
    }

    /// 应用行编辑：从后向前替换，计算最终文本和光标位置
    private static func applyLineEdits(
        text: String,
        replacements: [(range: NSRange, text: String)],
        originalSelections: [NSRange],
        cursorBehavior: CursorBehavior
    ) -> LineEditResult? {
        guard !replacements.isEmpty else { return nil }

        let nsText = text as NSString
        var mutableText = text

        // 计算总替换范围
        let firstRange = replacements.first!.range
        let lastRange = replacements.last!.range
        let totalRange = NSRange(
            location: firstRange.location,
            length: NSMaxRange(lastRange) - firstRange.location
        )

        // 从后向前应用替换，构建最终文本
        var offset = 0
        var replacementText = ""
        for (index, replacement) in replacements.enumerated() {
            if index > 0 {
                // 计算两个替换范围之间的原始文本
                let previousEnd = NSMaxRange(replacements[index - 1].range)
                let gapStart = previousEnd
                let gapEnd = replacement.range.location
                if gapEnd > gapStart {
                    let gapText = nsText.substring(with: NSRange(location: gapStart, length: gapEnd - gapStart))
                    replacementText += gapText
                }
            }
            replacementText += replacement.text
        }

        // 如果最后一个替换范围之后还有原始文本
        let lastEnd = NSMaxRange(lastRange)
        if lastEnd < NSMaxRange(totalRange) {
            // totalRange 已经包含了所有范围
        }

        // 直接构建完整的替换
        var result = ""
        // totalRange 之前的内容
        if totalRange.location > 0 {
            result += nsText.substring(with: NSRange(location: 0, length: totalRange.location))
        }

        // 在 totalRange 内，从后向前应用各个替换
        var segments: [(offset: Int, length: Int, replacement: String)] = []
        for replacement in replacements {
            segments.append((
                offset: replacement.range.location - totalRange.location,
                length: replacement.range.length,
                replacement: replacement.text
            ))
        }

        var reconstructed = ""
        var currentPos = 0
        for segment in segments {
            // segment 之前的原始内容
            if segment.offset > currentPos {
                let rangeInSegment = NSRange(
                    location: totalRange.location + currentPos,
                    length: segment.offset - currentPos
                )
                if NSMaxRange(rangeInSegment) <= nsText.length {
                    reconstructed += nsText.substring(with: rangeInSegment)
                }
            }
            reconstructed += segment.replacement
            currentPos = segment.offset + segment.length
        }
        // totalRange 末尾之前剩余的内容
        if currentPos < totalRange.length {
            let remainingStart = totalRange.location + currentPos
            let remainingLength = totalRange.length - currentPos
            if remainingStart + remainingLength <= nsText.length {
                reconstructed += nsText.substring(with: NSRange(
                    location: remainingStart,
                    length: remainingLength
                ))
            }
        }

        result += reconstructed

        // totalRange 之后的内容
        let afterTotalRange = NSMaxRange(totalRange)
        if afterTotalRange < nsText.length {
            result += nsText.substring(with: NSRange(
                location: afterTotalRange,
                length: nsText.length - afterTotalRange
            ))
        }

        // 计算新光标位置
        let newCursors: [NSRange]
        switch cursorBehavior {
        case .lineStart:
            // 光标放在替换后相应行的起始位置
            newCursors = originalSelections.map { _ in
                NSRange(location: totalRange.location, length: 0)
            }
        case .preserve:
            newCursors = originalSelections
        }

        return LineEditResult(
            replacementRange: NSRange(location: 0, length: nsText.length),
            replacementText: result,
            selectedRanges: newCursors
        )
    }

    /// 从后向前应用编辑（用于插入类操作，避免偏移干扰）
    private static func applyEditsFromBack(
        text: String,
        edits: [(range: NSRange, text: String)],
        newCursors: [NSRange]
    ) -> LineEditResult? {
        let nsText = text as NSString
        guard !edits.isEmpty else { return nil }

        var mutableText = text
        // 按位置从后向前排序
        let sortedEdits = edits.sorted { $0.range.location > $1.range.location }

        // 跟踪偏移量来修正 newCursors
        var adjustments: [(location: Int, delta: Int)] = []

        for edit in sortedEdits {
            let range = edit.range
            let insertText = edit.text
            let stringRange = Range(range, in: mutableText)
            guard let stringRange else { return nil }

            let insertedLength = (insertText as NSString).length
            if range.length == 0 {
                // 纯插入
                mutableText.insert(contentsOf: insertText, at: stringRange.lowerBound)
                adjustments.append((location: range.location, delta: insertedLength))
            } else {
                mutableText.replaceSubrange(stringRange, with: insertText)
                adjustments.append((location: range.location, delta: insertedLength - range.length))
            }
        }

        // 修正光标位置
        let adjustedCursors = newCursors.map { cursor -> NSRange in
            var adjustedLocation = cursor.location
            for adjustment in adjustments {
                if cursor.location > adjustment.location {
                    adjustedLocation += adjustment.delta
                }
            }
            return NSRange(location: adjustedLocation, length: cursor.length)
        }

        return LineEditResult(
            replacementRange: NSRange(location: 0, length: nsText.length),
            replacementText: mutableText,
            selectedRanges: adjustedCursors
        )
    }
}
