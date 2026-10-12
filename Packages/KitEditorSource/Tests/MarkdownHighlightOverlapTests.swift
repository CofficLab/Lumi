//
//  MarkdownHighlightOverlapTests.swift
//  EditorSource
//
//  Test to reproduce markdown highlight color overlap issue
//

import Foundation
import XCTest
@testable import EditorSource

/// Test to reproduce the issue where markdown headings with emphasis
/// (e.g., `# Hello **World**`) have overlapping capture ranges from
/// different tree-sitter layers (markdown + markdown_inline)
@MainActor
final class MarkdownHighlightOverlapTests: XCTestCase {

    // MARK: - Unit tests for StyledRangeContainer

    /// Test StyledRangeContainer behavior with conflicting captures
    func testStyledRangeContainerWithConflictingCaptures() {
        let documentLength = 100
        let providers = [0, 1]
        let container = StyledRangeContainer(documentLength: documentLength, providers: providers)

        // Provider 0 (higher priority, lower ID) gives .comment to range 10..<20
        let highlights0 = [
            HighlightRange(range: NSRange(location: 10, length: 10), capture: .comment)
        ]

        // Provider 1 (lower priority, higher ID) gives .string to range 15..<25
        // This overlaps with provider 0 at range 15..<20
        let highlights1 = [
            HighlightRange(range: NSRange(location: 15, length: 10), capture: .string)
        ]

        container.applyHighlightResult(
            provider: 0,
            highlights: highlights0,
            rangeToHighlight: NSRange(location: 0, length: documentLength)
        )

        container.applyHighlightResult(
            provider: 1,
            highlights: highlights1,
            rangeToHighlight: NSRange(location: 0, length: documentLength)
        )

        let runs = container.runsIn(range: NSRange(location: 0, length: documentLength))

        var overlapRunCapture: String?
        var location = 0
        for run in runs {
            let range = NSRange(location: location, length: run.length)
            if range.location <= 15 && range.max >= 20 {
                overlapRunCapture = run.value?.capture?.stringValue
            }
            location += run.length
        }

        XCTAssertEqual(overlapRunCapture, "comment",
            "Lower-ID provider (0, .comment) should win in overlap")
    }

    // MARK: - Unit tests for overlap detection

    /// Test that HighlightRange captures overlap detection
    func testHighlightRangeOverlapDetection() {
        let h1 = HighlightRange(range: NSRange(location: 0, length: 10), capture: .comment)
        let h2 = HighlightRange(range: NSRange(location: 5, length: 10), capture: .string)

        guard let intersection = h1.range.intersection(h2.range) else {
            XCTFail("Expected overlap but found none")
            return
        }

        XCTAssertTrue(intersection.length > 0, "Should have overlap")
    }

    /// Test multiple overlapping highlights from same layer
    func testMultipleOverlappingHighlights() {
        let highlights = [
            HighlightRange(range: NSRange(location: 0, length: 15), capture: .comment),
            HighlightRange(range: NSRange(location: 10, length: 10), capture: .string),
            HighlightRange(range: NSRange(location: 5, length: 20), capture: .keyword),
        ]

        let overlaps = findOverlappingCaptures(highlights)
        XCTAssertGreaterThan(overlaps.count, 0, "Should detect overlapping captures")
    }

    // MARK: - Unit tests for overlap resolution

    /// Overlapping ranges with equal length should keep the lower-priority capture.
    func testOverlappingRangesShouldBeDeduplicated() {
        let resolved = HighlightRangeOverlapResolver.resolveOverlaps([
            .init(range: NSRange(location: 0, length: 10), capture: .comment, modifiers: [], priority: 0),
            .init(range: NSRange(location: 5, length: 10), capture: .string, modifiers: [], priority: 1),
        ])

        XCTAssertEqual(resolved.count, 1)
        XCTAssertEqual(resolved[0].range, NSRange(location: 0, length: 10))
        XCTAssertEqual(resolved[0].capture, .comment)
    }

    /// Nested markdown captures should split into non-overlapping ranges.
    func testQueryHighlightsShouldNotReturnOverlappingRanges() {
        // Simulates tree-sitter output for "# Hello **World**":
        // - markdown layer: heading for "Hello **World**" (range 2..<17)
        // - markdown_inline layer: emphasis for "**World**" (range 8..<17)
        let markdownCaptures = HighlightRangeOverlapResolver.resolveOverlaps([
            .init(range: NSRange(location: 2, length: 15), capture: .keyword, modifiers: [], priority: 1),
            .init(range: NSRange(location: 8, length: 9), capture: .type, modifiers: [], priority: 0),
        ])

        let overlaps = findOverlappingCaptures(markdownCaptures)
        XCTAssertEqual(overlaps.count, 0,
            "Resolved highlights should not overlap")

        XCTAssertEqual(markdownCaptures.count, 2)
        XCTAssertEqual(markdownCaptures[0].range, NSRange(location: 2, length: 6))
        XCTAssertEqual(markdownCaptures[0].capture, .keyword)
        XCTAssertEqual(markdownCaptures[1].range, NSRange(location: 8, length: 9))
        XCTAssertEqual(markdownCaptures[1].capture, .type)
    }

    // MARK: - Helper Methods

    private func findOverlappingCaptures(_ highlights: [HighlightRange]) -> [(range: NSRange, capture1: CaptureName?, capture2: CaptureName?)] {
        var overlaps: [(range: NSRange, capture1: CaptureName?, capture2: CaptureName?)] = []

        for i in 0..<highlights.count {
            for j in (i+1)..<highlights.count {
                let h1 = highlights[i]
                let h2 = highlights[j]

                if let intersection = h1.range.intersection(h2.range), intersection.length > 0 {
                    if h1.capture != h2.capture {
                        overlaps.append((
                            range: intersection,
                            capture1: h1.capture,
                            capture2: h2.capture
                        ))
                    }
                }
            }
        }

        return overlaps
    }
}
