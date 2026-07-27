import Foundation

public enum LumiToolNameDeduplication {
    public static func validateUnique(tools: [any LumiAgentTool]) throws {
        let entries = tools.map { tool in
            ValidateEntry(name: tool.name, owner: String(reflecting: type(of: tool)))
        }
        try validateUnique(entries: entries)
    }

    public static func validateUnique(entries: [ValidateEntry]) throws {
        var ownersByName: [String: [String]] = [:]
        for entry in entries {
            ownersByName[entry.name, default: []].append(entry.owner)
        }
        let duplicates = ownersByName
            .filter { $0.value.count > 1 }
            .map { LumiToolDuplicateEntry(name: $0.key, owners: $0.value) }
            .sorted { $0.name < $1.name }
        if !duplicates.isEmpty {
            throw LumiToolRegistrationError.duplicateNames(duplicates)
        }
    }

    public static func assertUnique(tools: [any LumiAgentTool]) throws {
        try validateUnique(tools: tools)
    }

    public struct ValidateEntry: Sendable, Equatable {
        public let name: String
        public let owner: String
        public init(name: String, owner: String) { self.name = name; self.owner = owner }
    }
}
