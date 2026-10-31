import Foundation
import Testing
@testable import ProviderConversationInputBlock

@MainActor
@Suite("ConversationInputBlockProviding")
struct ConversationInputBlockProvidingTests {
    @Test("submitted blocks reach the observer")
    func submittedBlocksReachObserver() {
        let provider = DefaultConversationInputBlockProvider()
        var received: [ConversationInputBlock] = []
        let handle = provider.addObserver { event in
            guard case let .blockSubmitted(block) = event else { return }
            received.append(block)
        }

        let block = ConversationInputBlock(text: "let a = 1", title: "A.swift")
        provider.submit(block)

        #expect(received == [block])
        handle.cancel()
    }

    @Test("blocks submitted before any observer are replayed on registration")
    func blocksSubmittedEarlyAreReplayed() {
        let provider = DefaultConversationInputBlockProvider()

        provider.submit(ConversationInputBlock(text: "early", title: "Early"))

        var received: [ConversationInputBlock] = []
        provider.addObserver { event in
            guard case let .blockSubmitted(block) = event else { return }
            received.append(block)
        }

        #expect(received.map(\.text) == ["early"])
    }

    @Test("a cancelled observer stops receiving blocks")
    func cancelledObserverStopsReceiving() {
        let provider = DefaultConversationInputBlockProvider()
        var count = 0
        let handle = provider.addObserver { _ in count += 1 }

        provider.submit(ConversationInputBlock(text: "one", title: "One"))
        handle.cancel()
        provider.submit(ConversationInputBlock(text: "two", title: "Two"))

        #expect(count == 1)
    }

    @Test("empty text and empty titles are rejected")
    func rejectsEmptyBlocks() {
        let provider = DefaultConversationInputBlockProvider()
        var count = 0
        provider.addObserver { _ in count += 1 }

        provider.submit(ConversationInputBlock(text: "   \n", title: "Blank"))
        provider.submit(ConversationInputBlock(text: "let a = 1", title: ""))

        #expect(count == 0)
    }

    @Test("collapse threshold decides whether a block folds into a chip")
    func collapseThresholdDecidesFolding() {
        let short = ConversationInputBlock(text: "let a = 1", title: "A", collapseThreshold: 400)
        let long = ConversationInputBlock(
            text: String(repeating: "x", count: 500),
            title: "A",
            collapseThreshold: 400
        )

        #expect(!short.shouldCollapse)
        #expect(long.shouldCollapse)
    }

    @Test("an empty threshold collapses any non-empty text")
    func zeroThresholdCollapsesEverything() {
        let block = ConversationInputBlock(text: "let a = 1", title: "A")

        #expect(block.shouldCollapse)
    }

    @Test("negative thresholds are clamped to zero")
    func negativeThresholdIsClamped() {
        let block = ConversationInputBlock(text: "a", title: "A", collapseThreshold: -10)

        #expect(block.collapseThreshold == 0)
        #expect(block.shouldCollapse)
    }
}