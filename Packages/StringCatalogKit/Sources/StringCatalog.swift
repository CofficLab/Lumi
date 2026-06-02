import Foundation

public struct StringCatalog: Equatable, Sendable {
    public struct Language: Identifiable, Equatable, Sendable {
        public let id: String
        public let displayName: String
        public let completion: Double
        public let translatedCount: Int
        public let totalCount: Int
        public let isSourceLanguage: Bool

        public init(
            id: String,
            displayName: String,
            completion: Double,
            translatedCount: Int,
            totalCount: Int,
            isSourceLanguage: Bool
        ) {
            self.id = id
            self.displayName = displayName
            self.completion = completion
            self.translatedCount = translatedCount
            self.totalCount = totalCount
            self.isSourceLanguage = isSourceLanguage
        }
    }

    public struct Entry: Identifiable, Equatable, Sendable {
        public struct Value: Equatable, Sendable {
            public let text: String?
            public let state: String?

            public init(text: String?, state: String?) {
                self.text = text
                self.state = state
            }
        }

        public let id: String
        public let key: String
        public let extractionState: String?
        public let valuesByLanguage: [String: Value]

        public init(
            id: String,
            key: String,
            extractionState: String?,
            valuesByLanguage: [String: Value]
        ) {
            self.id = id
            self.key = key
            self.extractionState = extractionState
            self.valuesByLanguage = valuesByLanguage
        }
    }

    public let sourceLanguage: String
    public let languages: [Language]
    public let entries: [Entry]

    public init(sourceLanguage: String, languages: [Language], entries: [Entry]) {
        self.sourceLanguage = sourceLanguage
        self.languages = languages
        self.entries = entries
    }

    public var staleEntryCount: Int {
        entries.filter { $0.extractionState == "stale" }.count
    }
}
