import Foundation
import Testing
@testable import IdleTimePlugin

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

private func makeTemporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("PluginIdleTimeTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}
