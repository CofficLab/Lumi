import Foundation

enum MemoryToolInput {
    static let defaultMaxResults = 5
    static let minMaxResults = 0
    static let maxMaxResults = 20

    static func string(_ value: Any?) -> String? {
        guard let string = value as? String else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func scope(_ value: Any?, default defaultScope: String, allowed: Set<String>) throws -> String {
        guard let scope = string(value) else { return defaultScope }
        guard allowed.contains(scope) else {
            throw MemoryToolError.invalidArgument("scope must be one of: \(allowed.sorted().joined(separator: ", "))")
        }
        return scope
    }

    static func maxResults(
        _ value: Any?,
        default defaultValue: Int = defaultMaxResults,
        lowerBound: Int = minMaxResults,
        upperBound: Int = maxMaxResults
    ) -> Int {
        let requested: Int
        if let int = value as? Int {
            requested = int
        } else if let double = value as? Double {
            requested = Int(double)
        } else if let string = value as? String, let int = Int(string) {
            requested = int
        } else {
            requested = defaultValue
        }

        return min(max(requested, lowerBound), upperBound)
    }
}
