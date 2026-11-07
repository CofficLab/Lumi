import Foundation
import Testing
@testable import ProviderIdleTime

/// `IdleActivityStore` 的磁盘持久化测试（由旧版 PluginIdleTimeTests 迁移）。
@Suite("IdleActivityStore")
struct IdleActivityStoreTests {

    @Test func packageLoads() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = IdleActivityStore(directoryURL: directory)

        #expect(try await store.loadRecentEvents(since: .distantPast).isEmpty)
    }

    @Test func corruptEventsAreQuarantinedAndReplaced() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let eventsURL = directory.appendingPathComponent("activity.json")
        let corruptURL = IdleActivityStore.corruptFileURL(for: eventsURL)
        let invalidData = Data("not json".utf8)
        let staleData = Data("stale corrupt file".utf8)
        try staleData.write(to: corruptURL)
        try invalidData.write(to: eventsURL)

        let store = IdleActivityStore(directoryURL: directory)
        let events = try await store.loadRecentEvents(since: .distantPast)

        #expect(events.isEmpty)
        #expect((try? Data(contentsOf: corruptURL)) == invalidData)
        #expect(!FileManager.default.fileExists(atPath: eventsURL.path))
    }

    @Test func corruptSnapshotIsQuarantinedAndReplaced() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let snapshotURL = directory.appendingPathComponent("snapshot.json")
        let corruptURL = IdleActivityStore.corruptFileURL(for: snapshotURL)
        let invalidData = Data("not json".utf8)
        let staleData = Data("stale corrupt file".utf8)
        try staleData.write(to: corruptURL)
        try invalidData.write(to: snapshotURL)

        let store = IdleActivityStore(directoryURL: directory)
        let snapshot = try await store.loadSnapshot()

        #expect(snapshot == nil)
        #expect((try? Data(contentsOf: corruptURL)) == invalidData)
        #expect(!FileManager.default.fileExists(atPath: snapshotURL.path))
    }

    @Test func appendAndPrunePersistEvents() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = IdleActivityStore(directoryURL: directory)
        let now = Date()
        try await store.append(IdleActivityEvent(timestamp: now, kind: .editorInput))
        try await store.append(IdleActivityEvent(timestamp: now.addingTimeInterval(-10 * 60), kind: .fileSave))

        // 最近 5 分钟内只有 editorInput 事件。
        let recent = try await store.loadRecentEvents(since: now.addingTimeInterval(-5 * 60))
        #expect(recent.count == 1)
        #expect(recent.first?.kind == .editorInput)

        // prune 掉 5 分钟前的事件后，只剩 editorInput。
        try await store.prune(before: now.addingTimeInterval(-5 * 60))
        let remaining = try await store.loadRecentEvents(since: .distantPast)
        #expect(remaining.count == 1)
        #expect(remaining.first?.kind == .editorInput)
    }

    @Test func saveAndLoadSnapshotRoundTrip() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = IdleActivityStore(directoryURL: directory)
        let now = Date()
        let snapshot = IdleInferenceSnapshot(
            restWindow: RestWindow(
                startMinuteOfDay: 22 * 60 + 30,
                endMinuteOfDay: 7 * 60 + 30,
                confidence: 0.8,
                source: .weekday,
                generatedAt: now
            ),
            observedDayCount: 5,
            eventCount: 12,
            lastActivityAt: now,
            bucketScores: [0.1, 0.2],
            confidenceBreakdown: ConfidenceBreakdown(dataCoverage: 0.5, contrast: 0.6, stability: 0.7)
        )

        try await store.saveSnapshot(snapshot)
        let loaded = try await store.loadSnapshot()

        // 存储使用 ISO8601（秒级精度），Date 字段往返后亚秒被截断；逐字段比较。
        #expect(loaded != nil)
        #expect(wholeSecond(loaded?.restWindow?.generatedAt) == wholeSecond(snapshot.restWindow?.generatedAt))
        #expect(wholeSecond(loaded?.lastActivityAt) == wholeSecond(snapshot.lastActivityAt))
        #expect(loaded?.restWindow?.startMinuteOfDay == snapshot.restWindow?.startMinuteOfDay)
        #expect(loaded?.restWindow?.endMinuteOfDay == snapshot.restWindow?.endMinuteOfDay)
        #expect(loaded?.restWindow?.confidence == snapshot.restWindow?.confidence)
        #expect(loaded?.restWindow?.source == snapshot.restWindow?.source)
        #expect(loaded?.observedDayCount == snapshot.observedDayCount)
        #expect(loaded?.eventCount == snapshot.eventCount)
        #expect(loaded?.bucketScores == snapshot.bucketScores)
        #expect(loaded?.confidenceBreakdown == snapshot.confidenceBreakdown)
    }

    private func wholeSecond(_ date: Date?) -> TimeInterval? {
        guard let date else { return nil }
        return date.timeIntervalSince1970.rounded(.down)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProviderIdleTimeTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
