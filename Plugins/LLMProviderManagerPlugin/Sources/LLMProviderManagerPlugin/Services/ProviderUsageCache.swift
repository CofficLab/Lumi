import Foundation
import KernelLumi
import SwiftData
import os

@Model
final class ProviderUsageCacheEntry {
    var providerID: String
    var day: Date
    var inputTokens: Int
    var outputTokens: Int

    init(providerID: String, day: Date, inputTokens: Int, outputTokens: Int) {
        self.providerID = providerID
        self.day = day
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
    }
}

/// SwiftData cache for provider token usage.
///
/// Historical days are stable enough to cache. The current day is deliberately
/// kept live by the settings view so a completed request can appear immediately
/// after the next refresh.
@MainActor
final class ProviderUsageCache {
    static let databaseFileName = "provider-usage.sqlite"

    private let container: ModelContainer?
    let directory: URL

    init(storageDirectory: URL?) {
        let directory = storageDirectory ?? FileManager.default.temporaryDirectory
            .appendingPathComponent("Lumi/LLMProviderManager", isDirectory: true)
        self.directory = directory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let schema = Schema([ProviderUsageCacheEntry.self])
        let configuration = ModelConfiguration(
            "LLMProviderManagerUsage",
            schema: schema,
            url: directory.appendingPathComponent(Self.databaseFileName),
            allowsSave: true,
            cloudKitDatabase: .none
        )

        do {
            self.container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            self.container = nil
            Logger(subsystem: "com.coffic.lumi", category: "plugin.llm-provider-manager")
                .error("Provider usage cache initialization failed: \(error.localizedDescription)")
        }
    }

    func load(providerID: String, days: [Date]) -> [Date: MessageTokenUsage] {
        guard let container, !days.isEmpty else { return [:] }

        let normalizedDays = Set(days.map { Calendar.current.startOfDay(for: $0) })
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<ProviderUsageCacheEntry>(
            predicate: #Predicate {
                $0.providerID == providerID && normalizedDays.contains($0.day)
            }
        )

        guard let entries = try? context.fetch(descriptor) else { return [:] }
        return Dictionary(uniqueKeysWithValues: entries.map {
            ($0.day, MessageTokenUsage(day: $0.day, inputTokens: $0.inputTokens, outputTokens: $0.outputTokens))
        })
    }

    func save(_ usages: [MessageTokenUsage], providerID: String) {
        guard let container, !usages.isEmpty else { return }

        let context = ModelContext(container)
        let days = Set(usages.map { Calendar.current.startOfDay(for: $0.day) })
        let descriptor = FetchDescriptor<ProviderUsageCacheEntry>(
            predicate: #Predicate {
                $0.providerID == providerID && days.contains($0.day)
            }
        )

        do {
            let existing = try context.fetch(descriptor)
            var entries = Dictionary(uniqueKeysWithValues: existing.map { ($0.day, $0) })

            for usage in usages {
                let day = Calendar.current.startOfDay(for: usage.day)
                if let entry = entries[day] {
                    entry.inputTokens = usage.inputTokens
                    entry.outputTokens = usage.outputTokens
                } else {
                    let entry = ProviderUsageCacheEntry(
                        providerID: providerID,
                        day: day,
                        inputTokens: usage.inputTokens,
                        outputTokens: usage.outputTokens
                    )
                    context.insert(entry)
                    entries[day] = entry
                }
            }

            try context.save()
        } catch {
            Logger(subsystem: "com.coffic.lumi", category: "plugin.llm-provider-manager")
                .error("Provider usage cache save failed: \(error.localizedDescription)")
        }
    }
}
