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

@Suite struct ChatSlashCommandTests {

    @Test func suggestionsEmptyWithoutLeadingSlash() {
        #expect(ChatSlashCommand.suggestions(for: "clear").isEmpty)
        #expect(ChatSlashCommand.suggestions(for: "hello").isEmpty)
    }

    @Test func suggestionsReturnsMatchingCommands() {
        let result = ChatSlashCommand.suggestions(for: "/c")
        #expect(result.map(\.command) == ["/clear"])
    }

    @Test func suggestionsAllWhenJustSlash() {
        let result = ChatSlashCommand.suggestions(for: "/")
        #expect(result.count == ChatSlashCommand.all.count)
    }

    @Test func suggestionsIsCaseInsensitive() {
        let upper = ChatSlashCommand.suggestions(for: "/CLEAR")
        #expect(upper.map(\.command) == ["/clear"])
    }

    @Test func suggestionsRequiresLeadingSlash() {
        // The "/" guard checks the raw input before trimming, so leading
        // whitespace prevents matching — documented behavior.
        #expect(ChatSlashCommand.suggestions(for: "  /he ").isEmpty)
        // Trailing whitespace is fine: "/he " → trimmed "/he" still matches.
        let trailing = ChatSlashCommand.suggestions(for: "/he ")
        #expect(trailing.map(\.command) == ["/help"])
    }

    @Test func suggestionsEmptyForUnknownPrefix() {
        #expect(ChatSlashCommand.suggestions(for: "/xyz").isEmpty)
    }

    @Test func catalogContainsCoreCommands() {
        let commands = ChatSlashCommand.all.map(\.command)
        #expect(commands.contains("/clear"))
        #expect(commands.contains("/help"))
        #expect(commands.contains("/model"))
    }
}

@Suite struct ChatScreenshotCropTests {

    /// Build a solid-color CGImage of the given pixel size for crop tests.
    private func makeImage(width: Int, height: Int) -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)
        // Fill with opaque white.
        for i in stride(from: 0, to: pixels.count, by: 4) {
            pixels[i] = 255; pixels[i + 1] = 255; pixels[i + 2] = 255; pixels[i + 3] = 255
        }
        let provider = CGDataProvider(data: Data(bytes: &pixels, count: pixels.count) as CFData)!
        return CGImage(
            width: width, height: height,
            bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
        )!
    }

    @Test func cropReturnsImageForValidSelection() {
        let image = makeImage(width: 200, height: 100)
        let captureFrame = CGRect(x: 0, y: 0, width: 400, height: 200)
        // Selection covers the top-left quarter of the capture (200x100 screen → 100x50 px).
        let selection = CGRect(x: 0, y: 100, width: 200, height: 100)
        let cropped = ChatScreenshotState.crop(image: image, captureFrame: captureFrame, selection: selection)
        #expect(cropped != nil)
        #expect(cropped!.width >= 99)   // ~100px after integral rounding
        #expect(cropped!.height >= 49)  // ~50px
    }

    @Test func cropReturnsNilForOutOfImageSelection() {
        let image = makeImage(width: 100, height: 100)
        let captureFrame = CGRect(x: 0, y: 0, width: 100, height: 100)
        // A selection entirely outside the image intersects to nothing (< 1px).
        let selection = CGRect(x: 500, y: 500, width: 10, height: 10)
        let cropped = ChatScreenshotState.crop(image: image, captureFrame: captureFrame, selection: selection)
        #expect(cropped == nil)
    }

    @Test func cropClampsSelectionToImageBounds() {
        let image = makeImage(width: 100, height: 100)
        let captureFrame = CGRect(x: 0, y: 0, width: 100, height: 100)
        // Selection extends beyond the capture frame; must be intersected.
        let selection = CGRect(x: -50, y: -50, width: 300, height: 300)
        let cropped = ChatScreenshotState.crop(image: image, captureFrame: captureFrame, selection: selection)
        #expect(cropped != nil)
        #expect(cropped!.width <= 100)
        #expect(cropped!.height <= 100)
    }
}
