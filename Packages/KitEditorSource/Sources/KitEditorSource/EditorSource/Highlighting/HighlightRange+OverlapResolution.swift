//
//  HighlightRange+OverlapResolution.swift
//  EditorSource
//

import Foundation

enum HighlightRangeOverlapResolver {
    struct PrioritizedHighlight: Sendable {
        let range: NSRange
        let capture: CaptureName?
        let modifiers: CaptureModifierSet
        let priority: Int
    }

    /// Resolves overlapping highlight ranges into non-overlapping segments.
    ///
    /// Shorter ranges win in overlap regions (nested captures keep inner styling).
    /// When ranges share the same length, lower `priority` values win.
    static func resolveOverlaps(
        _ highlights: [PrioritizedHighlight],
        in includedRange: NSRange? = nil
    ) -> [HighlightRange] {
        let scoped = highlights.compactMap { item -> PrioritizedHighlight? in
            let range: NSRange
            if let includedRange {
                guard let intersection = item.range.intersection(includedRange), !intersection.isEmpty else {
                    return nil
                }
                range = intersection
            } else {
                range = item.range
            }
            guard !range.isEmpty else { return nil }
            return PrioritizedHighlight(
                range: range,
                capture: item.capture,
                modifiers: item.modifiers,
                priority: item.priority
            )
        }

        let sorted = scoped.sorted {
            if $0.range.length != $1.range.length {
                return $0.range.length < $1.range.length
            }
            if $0.priority != $1.priority {
                return $0.priority < $1.priority
            }
            return $0.range.location < $1.range.location
        }

        var result: [HighlightRange] = []
        var occupied = IndexSet()
        var accepted: [PrioritizedHighlight] = []

        for item in sorted {
            let fullRange = IndexSet(integersIn: item.range)
            let available = fullRange.subtracting(occupied)
            guard !available.isEmpty else { continue }

            if available != fullRange {
                let hasNonNestedBlocker = accepted.contains { existing in
                    guard existing.priority < item.priority,
                          let intersection = item.range.intersection(existing.range),
                          intersection.length > 0 else {
                        return false
                    }
                    return existing.range.length >= item.range.length
                }
                if hasNonNestedBlocker {
                    continue
                }
            }

            for subrange in available.rangeView {
                let nsRange = NSRange(subrange)
                result.append(HighlightRange(range: nsRange, capture: item.capture, modifiers: item.modifiers))
            }
            accepted.append(item)
            occupied.formUnion(available)
        }

        return result.sorted { $0.range.location < $1.range.location }
    }
}
