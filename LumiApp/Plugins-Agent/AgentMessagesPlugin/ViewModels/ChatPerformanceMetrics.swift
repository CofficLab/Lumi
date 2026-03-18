import Foundation
import OSLog

@MainActor
final class ChatPerformanceMetrics {
    static let shared = ChatPerformanceMetrics()

    private let logger = Logger(subsystem: "Lumi", category: "ChatPerf")

    private(set) var markdownRenderCount: Int = 0
    private(set) var metadataCacheHitCount: Int = 0
    private(set) var metadataCacheMissCount: Int = 0
    private(set) var toolTimelineRenderCount: Int = 0

    private var renderedMarkdownKeys = Set<String>()

    func markMarkdownRendered(messageId: UUID, contentHash: Int) {
        let key = "\(messageId.uuidString)-\(contentHash)"
        guard !renderedMarkdownKeys.contains(key) else { return }
        renderedMarkdownKeys.insert(key)
        markdownRenderCount += 1
        maybeLogSnapshot()
    }

    func markMetadataCacheHit() {
        metadataCacheHitCount += 1
        maybeLogSnapshot()
    }

    func markMetadataCacheMiss() {
        metadataCacheMissCount += 1
        maybeLogSnapshot()
    }

    func markToolTimelineRendered() {
        toolTimelineRenderCount += 1
        maybeLogSnapshot()
    }

    private func maybeLogSnapshot() {
        let total = markdownRenderCount + metadataCacheHitCount + metadataCacheMissCount + toolTimelineRenderCount
        guard total > 0, total % 100 == 0 else { return }
        logger.info(
            "chat-perf snapshot markdown=\(self.markdownRenderCount) cacheHit=\(self.metadataCacheHitCount) cacheMiss=\(self.metadataCacheMissCount) toolTimeline=\(self.toolTimelineRenderCount)"
        )
    }
}

