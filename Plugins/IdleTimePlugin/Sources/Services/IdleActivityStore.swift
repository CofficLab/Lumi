import Foundation
import LumiKernel

public actor IdleActivityStore {
    public static let shared = IdleActivityStore()

    private let fileManager: FileManager
    private let directoryURL: URL
    private let eventsURL: URL
    private let snapshotURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        fileManager: FileManager = .default,
        directoryURL: URL? = nil
    ) {
        self.fileManager = fileManager
        let root = directoryURL
            ?? IdleTimeRuntimeBridge.directoryURL
            ?? FileManager.default.temporaryDirectory
                .appendingPathComponent("IdleTimePlugin", isDirectory: true)
        self.directoryURL = root
        self.eventsURL = root.appendingPathComponent("activity.json")
        self.snapshotURL = root.appendingPathComponent("snapshot.json")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        try? fileManager.createDirectory(at: root, withIntermediateDirectories: true)
    }

    public func append(_ event: IdleActivityEvent) async throws {
        var events = try loadEvents()
        events.append(event)
        try writeEvents(events)
    }

    public func loadRecentEvents(since cutoff: Date) async throws -> [IdleActivityEvent] {
        try loadEvents().filter { $0.timestamp >= cutoff }
    }

    public func saveSnapshot(_ snapshot: IdleInferenceSnapshot) async throws {
        try ensureDirectory()
        let data = try encoder.encode(snapshot)
        try data.write(to: snapshotURL, options: .atomic)
    }

    public func loadSnapshot() async throws -> IdleInferenceSnapshot? {
        guard fileManager.fileExists(atPath: snapshotURL.path) else { return nil }
        do {
            let data = try Data(contentsOf: snapshotURL)
            return try decoder.decode(IdleInferenceSnapshot.self, from: data)
        } catch {
            quarantineCorruptFile(snapshotURL)
            return nil
        }
    }

    public func prune(before cutoff: Date) async throws {
        let events = try loadEvents().filter { $0.timestamp >= cutoff }
        try writeEvents(events)
    }

    private func loadEvents() throws -> [IdleActivityEvent] {
        guard fileManager.fileExists(atPath: eventsURL.path) else { return [] }
        do {
            let data = try Data(contentsOf: eventsURL)
            return try decoder.decode([IdleActivityEvent].self, from: data)
        } catch {
            quarantineCorruptFile(eventsURL)
            return []
        }
    }

    private func writeEvents(_ events: [IdleActivityEvent]) throws {
        try ensureDirectory()
        let data = try encoder.encode(events)
        try data.write(to: eventsURL, options: .atomic)
    }

    private func ensureDirectory() throws {
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    static func corruptFileURL(for url: URL) -> URL {
        url.deletingPathExtension()
            .appendingPathExtension("corrupt.json")
    }

    private func quarantineCorruptFile(_ url: URL) {
        let quarantineURL = Self.corruptFileURL(for: url)
        do {
            if fileManager.fileExists(atPath: quarantineURL.path) {
                try fileManager.removeItem(at: quarantineURL)
            }
            try fileManager.moveItem(at: url, to: quarantineURL)
        } catch {
            // Recovery is best-effort; a stale activity cache should not break app usage.
        }
    }
}
