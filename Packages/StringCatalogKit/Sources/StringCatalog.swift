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

    // MARK: - Translation Issues

    /// 翻译问题类型。
    public enum TranslationIssueKind: String, Sendable {
        /// 非源语言翻译值与 key 完全相同（未实际翻译）。
        case untranslated
        /// 非源语言缺少翻译条目。
        case missing
    }

    /// 单个翻译问题。
    public struct TranslationIssue: Equatable, Sendable {
        public let key: String
        public let language: String
        public let kind: TranslationIssueKind

        public init(key: String, language: String, kind: TranslationIssueKind) {
            self.key = key
            self.language = language
            self.kind = kind
        }
    }

    /// 翻译问题摘要。
    public struct TranslationIssuesSummary: Equatable, Sendable {
        public let issues: [TranslationIssue]

        public init(issues: [TranslationIssue]) {
            self.issues = issues
        }

        public var isEmpty: Bool { issues.isEmpty }

        public var totalCount: Int { issues.count }

        /// 按语言分组的问题数量。
        public var countByLanguage: [String: Int] {
            Dictionary(grouping: issues, by: \.language).mapValues { $0.count }
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

    public var staleEntryKeys: [String] {
        entries
            .filter { $0.extractionState == "stale" }
            .map(\.key)
            .sorted()
    }

    /// 检测翻译问题：未翻译和缺失翻译。
    public var translationIssues: TranslationIssuesSummary {
        let nonSourceLanguages = languages.filter { !$0.isSourceLanguage }.map(\.id)
        var issues: [TranslationIssue] = []

        for entry in entries where entry.extractionState != "stale" {
            for language in nonSourceLanguages {
                if let value = entry.valuesByLanguage[language] {
                    // 有条目但值和 key 一样 → 未翻译
                    if let text = value.text, !text.isEmpty, text == entry.key {
                        issues.append(TranslationIssue(
                            key: entry.key,
                            language: language,
                            kind: .untranslated
                        ))
                    }
                } else {
                    // 完全没有这个语言的条目 → 缺失
                    issues.append(TranslationIssue(
                        key: entry.key,
                        language: language,
                        kind: .missing
                    ))
                }
            }
        }

        return TranslationIssuesSummary(issues: issues)
    }
}
