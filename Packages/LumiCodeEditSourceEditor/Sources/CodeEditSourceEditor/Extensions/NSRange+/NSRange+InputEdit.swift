//
//  NSRange+InputEdit.swift
//  CodeEditSourceEditor
//
//  Created by Khan Winter on 9/12/22.
//

import Foundation
import CodeEditTextView
import SwiftTreeSitter

extension InputEdit {
    init?(range: NSRange, delta: Int, oldEndPoint: Point, textView: TextView) {
        guard let oldEndLocation = range.treeSitterEndLocation,
              let startByte = range.location.treeSitterUTF16ByteOffset,
              let oldEndByte = oldEndLocation.treeSitterUTF16ByteOffset else {
            assertionFailure("Invalid range")
            return nil
        }

        let newEnd = oldEndLocation.addingReportingOverflow(delta)
        let newLength = range.length.addingReportingOverflow(delta)

        guard !newEnd.overflow,
              !newLength.overflow,
              newLength.partialValue >= 0,
              let newEndByte = newEnd.partialValue.treeSitterUTF16ByteOffset else {
            assertionFailure("Invalid range/delta")
            return nil
        }

        let newEndLocation = newEnd.partialValue

        let startPoint = textView.pointForLocation(range.location) ?? .zero
        let newEndPoint = textView.pointForLocation(newEndLocation) ?? .zero

        self.init(
            startByte: startByte,
            oldEndByte: oldEndByte,
            newEndByte: newEndByte,
            startPoint: startPoint,
            oldEndPoint: oldEndPoint,
            newEndPoint: newEndPoint
        )
    }
}

extension NSRange {
    // swiftlint:disable line_length
    /// Modifies the range to account for an edit.
    /// Largely based on code from
    /// [tree-sitter](https://github.com/tree-sitter/tree-sitter/blob/ddeaa0c7f534268b35b4f6cb39b52df082754413/lib/src/subtree.c#L691-L720)
    mutating func applyInputEdit(_ edit: InputEdit) {
        // swiftlint:enable line_length
        let endIndex = NSMaxRange(self)
        let isPureInsertion = edit.oldEndByte == edit.startByte

        // Edit is after the range
        if (edit.startByte/2) > endIndex {
            return
        } else if edit.oldEndByte/2 < location {
            // If the edit is entirely before this range
            self.location += (Int(edit.newEndByte) - Int(edit.oldEndByte))/2
        } else if edit.startByte/2 < location {
            // If the edit starts in the space before this range and extends into this range
            length -= Int(edit.oldEndByte)/2 - location
            location = Int(edit.newEndByte)/2
        } else if edit.startByte/2 == location && isPureInsertion {
            // If the edit is *only* an insertion right at the beginning of the range
            location = Int(edit.newEndByte)/2
        } else {
            // Otherwise, the edit is entirely within this range
            if edit.startByte/2 < endIndex || (edit.startByte/2 == endIndex && isPureInsertion) {
                length = (Int(edit.newEndByte)/2 - location) + (length - (Int(edit.oldEndByte)/2 - location))
            }
        }
    }
}
