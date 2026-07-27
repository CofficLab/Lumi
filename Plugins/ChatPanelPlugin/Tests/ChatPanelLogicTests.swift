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
