//
//  NSRange+TSRange.swift
//  EditorSource
//
//  Created by Khan Winter on 2/26/23.
//

import Foundation
import SwiftTreeSitter

extension Int {
    var treeSitterUTF16ByteOffset: UInt32? {
        guard self >= 0, self <= Int(UInt32.max / 2) else {
            return nil
        }

        return UInt32(self * 2)
    }
}

extension NSRange {
    var treeSitterEndLocation: Int? {
        guard location >= 0, length >= 0 else {
            return nil
        }

        let endLocation = location.addingReportingOverflow(length)
        guard !endLocation.overflow else {
            return nil
        }

        return endLocation.partialValue
    }

    var treeSitterByteRange: Range<UInt32>? {
        guard let endLocation = treeSitterEndLocation,
              let startByte = location.treeSitterUTF16ByteOffset,
              let endByte = endLocation.treeSitterUTF16ByteOffset else {
            return nil
        }

        return startByte..<endByte
    }

    var tsRange: TSRange? {
        guard let byteRange = treeSitterByteRange else {
            return nil
        }

        return TSRange(
            points: .zero..<(.zero),
            bytes: byteRange
        )
    }
}
