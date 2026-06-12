enum GitHubToolArgumentNormalizer {
    static let minIssueNumber = 1
    static let minPage = 1
    static let minPerPage = 1
    static let maxPerPage = 100

    static func integer(_ value: Any?) -> Int? {
        if let int = value as? Int {
            return int
        }
        if let double = value as? Double {
            return Int(double)
        }
        if let string = value as? String {
            return Int(string)
        }
        return nil
    }

    static func issueNumber(_ value: Any?) -> Int? {
        guard let raw = integer(value), raw >= minIssueNumber else { return nil }
        return raw
    }

    static func nonNegativeInteger(_ value: Any?) -> Int {
        max(integer(value) ?? 0, 0)
    }

    static func page(_ value: Any?) -> Int {
        max(integer(value) ?? minPage, minPage)
    }

    static func perPage(_ value: Any?) -> Int {
        min(max(integer(value) ?? 10, minPerPage), maxPerPage)
    }
}
