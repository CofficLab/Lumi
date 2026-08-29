import Combine
import Foundation

/// A lightweight, plugin-owned usage record for one LLM provider.
struct ProviderUsageRecord: Codable, Equatable, Sendable {
    var count: Int
    var lastUsedAt: Date
}

/// Persists approximate provider usage for the Model Selector plugin.
///
/// This store intentionally records only provider IDs, counts, and timestamps.
/// It does not depend on conversation storage or the LLM manager's routing
/// implementation, so the "Frequent" scope remains a self-contained UI
/// feature.
@MainActor
final class ProviderUsageStore: ObservableObject {
    private static let fileName = "provider-usage.json"

    @Published private(set) var records: [String: ProviderUsageRecord] = [:]

    private let fileURL: URL?

    init(directory: URL?) {
        if let directory {
            try? FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            fileURL = directory.appendingPathComponent(Self.fileName)
        } else {
            fileURL = nil
        }

        load()
    }

    var hasAnyUsage: Bool {
        !records.isEmpty
    }

    func usageCount(for providerID: String) -> Int {
        records[providerID]?.count ?? 0
    }

    func lastUsedAt(for providerID: String) -> Date? {
        records[providerID]?.lastUsedAt
    }

    func recordUse(providerID: String, at date: Date = Date()) {
        let normalizedID = providerID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedID.isEmpty else { return }

        let previousCount = records[normalizedID]?.count ?? 0
        records[normalizedID] = ProviderUsageRecord(
            count: previousCount + 1,
            lastUsedAt: date
        )
        save()
    }

    /// Sorts higher-use providers first, then uses recency and ID as stable
    /// tie-breakers so the list does not jump between refreshes.
    func isMoreFrequentlyUsed(_ lhs: String, than rhs: String) -> Bool {
        let left = records[lhs]
        let right = records[rhs]

        if left?.count != right?.count {
            return (left?.count ?? 0) > (right?.count ?? 0)
        }
        if left?.lastUsedAt != right?.lastUsedAt {
            return (left?.lastUsedAt ?? .distantPast) > (right?.lastUsedAt ?? .distantPast)
        }
        return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
    }

    private func load() {
        guard let fileURL,
              let data = try? Data(contentsOf: fileURL),
              let decoded = try? Self.decoder.decode(
                  [String: ProviderUsageRecord].self,
                  from: data
              )
        else {
            return
        }
        records = decoded
    }

    private func save() {
        guard let fileURL,
              let data = try? Self.encoder.encode(records)
        else {
            return
        }
        try? data.write(to: fileURL, options: .atomic)
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
