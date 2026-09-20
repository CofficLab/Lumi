//
//  String+NSRange.swift
//  EditorSource
//
//  Created by Lukas Pistrol on 25.05.22.
//

import Foundation

extension String {
    // make string subscriptable with NSRange
    subscript(value: NSRange) -> Substring? {
        // 先校验范围：越界的 NSRange（超出 utf16 长度或为负）
        // 应返回 nil，而不是让 String.Index(utf16Offset:) 崩溃。
        let utf16Length = utf16.count
        guard value.lowerBound >= 0,
              value.upperBound >= value.lowerBound,
              value.upperBound <= utf16Length else {
            return nil
        }
        let upperBound = String.Index(utf16Offset: Int(value.upperBound), in: self)
        let lowerBound = String.Index(utf16Offset: Int(value.lowerBound), in: self)
        return self[lowerBound..<upperBound]
    }
}
