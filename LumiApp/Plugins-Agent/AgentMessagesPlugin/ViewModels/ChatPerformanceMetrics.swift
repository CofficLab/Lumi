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
    private(set) var messageBubbleAppearCount: Int = 0
    private(set) var messageBubbleDisappearCount: Int = 0
    private(set) var markdownAppearCount: Int = 0
    private(set) var markdownDisappearCount: Int = 0
    private(set) var displayRowsBuildCount: Int = 0
    private(set) var displayRowsBuildTimeMsTotal: Double = 0
    private(set) var displayRowsBuildSlowCount: Int = 0

    private var renderedMarkdownKeys = Set<String>()
    private var visibleBubbleIDs = Set<UUID>()
    private var visibleMarkdownIDs = Set<UUID>()

    private func emitToConsole(_ message: String) {
        os_log("%{public}@", log: .default, type: .info, message)
    }

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

    func markDisplayRowsBuilt(
        source: String,
        windowedMessageCount: Int,
        displayRowsCount: Int,
        toolOutputLookupCount: Int,
        durationMs: Double
    ) {
        displayRowsBuildCount += 1
        displayRowsBuildTimeMsTotal += durationMs

        if durationMs >= 10 {
            displayRowsBuildSlowCount += 1
            let line = "chat-perf slow-build source=\(source) windowed=\(windowedMessageCount) rows=\(displayRowsCount) toolLookup=\(toolOutputLookupCount) durationMs=\(String(format: "%.2f", durationMs))"
            logger.warning("\(line, privacy: .public)")
            emitToConsole(line)
        } else if displayRowsBuildCount % 40 == 0 {
            let avg = displayRowsBuildTimeMsTotal / Double(max(displayRowsBuildCount, 1))
            let line = "chat-perf build-snapshot count=\(self.displayRowsBuildCount) avgMs=\(String(format: "%.2f", avg)) slow=\(self.displayRowsBuildSlowCount)"
            logger.info("\(line, privacy: .public)")
            emitToConsole(line)
        }
    }

    func markMessageBubbleVisibility(messageId: UUID, role: MessageRole, appeared: Bool) {
        if appeared {
            messageBubbleAppearCount += 1
            visibleBubbleIDs.insert(messageId)
        } else {
            messageBubbleDisappearCount += 1
            visibleBubbleIDs.remove(messageId)
        }

        if (messageBubbleAppearCount + messageBubbleDisappearCount) % 80 == 0 {
            let line = "chat-perf bubble-visibility visible=\(self.visibleBubbleIDs.count) appear=\(self.messageBubbleAppearCount) disappear=\(self.messageBubbleDisappearCount) role=\(role.rawValue)"
            logger.info("\(line, privacy: .public)")
            emitToConsole(line)
        }
    }

    func markMarkdownVisibility(messageId: UUID, appeared: Bool) {
        if appeared {
            markdownAppearCount += 1
            visibleMarkdownIDs.insert(messageId)
        } else {
            markdownDisappearCount += 1
            visibleMarkdownIDs.remove(messageId)
        }

        if (markdownAppearCount + markdownDisappearCount) % 80 == 0 {
            let line = "chat-perf markdown-visibility visible=\(self.visibleMarkdownIDs.count) appear=\(self.markdownAppearCount) disappear=\(self.markdownDisappearCount)"
            logger.info("\(line, privacy: .public)")
            emitToConsole(line)
        }
    }

    private func maybeLogSnapshot() {
        let total = markdownRenderCount + metadataCacheHitCount + metadataCacheMissCount + toolTimelineRenderCount
        guard total > 0, total % 100 == 0 else { return }
        logger.info(
            "chat-perf snapshot markdown=\(self.markdownRenderCount) cacheHit=\(self.metadataCacheHitCount) cacheMiss=\(self.metadataCacheMissCount) toolTimeline=\(self.toolTimelineRenderCount) bubbleVisible=\(self.visibleBubbleIDs.count) markdownVisible=\(self.visibleMarkdownIDs.count)"
        )
        emitToConsole(
            "chat-perf snapshot markdown=\(self.markdownRenderCount) cacheHit=\(self.metadataCacheHitCount) cacheMiss=\(self.metadataCacheMissCount) toolTimeline=\(self.toolTimelineRenderCount) bubbleVisible=\(self.visibleBubbleIDs.count) markdownVisible=\(self.visibleMarkdownIDs.count)"
        )
    }
}
