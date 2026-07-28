import Testing
import CoreGraphics
import Foundation
@testable import ChatPanelPlugin

/// Unit tests for the pure logic in ChatPanelPlugin: split-width clamping,
/// slash-command suggestion matching, and screenshot crop geometry.
@Suite struct SplitWidthClampTests {

    @Test func clampKeepsValueWithinBounds() {
        #expect(SplitWidth.clamp(300) == 300)
        #expect(SplitWidth.clamp(500) == 500)
    }

    @Test func clampRaisesBelowMinimum() {
        #expect(SplitWidth.clamp(100) == SplitWidth.defaultMinimumWidth)
        #expect(SplitWidth.clamp(0) == SplitWidth.defaultMinimumWidth)
        #expect(SplitWidth.clamp(-50) == SplitWidth.defaultMinimumWidth)
    }

    @Test func clampLowersAboveMaximum() {
        #expect(SplitWidth.clamp(2000) == SplitWidth.defaultMaximumWidth)
        #expect(SplitWidth.clamp(960) == SplitWidth.defaultMaximumWidth)
    }

    @Test func clampAtBoundaries() {
        #expect(SplitWidth.clamp(220) == 220)
        #expect(SplitWidth.clamp(960) == 960)
    }

    @Test func clampRespectsCustomBounds() {
        #expect(SplitWidth.clamp(50, minimum: 100, maximum: 500) == 100)
        #expect(SplitWidth.clamp(600, minimum: 100, maximum: 500) == 500)
        #expect(SplitWidth.clamp(300, minimum: 100, maximum: 500) == 300)
    }
}


