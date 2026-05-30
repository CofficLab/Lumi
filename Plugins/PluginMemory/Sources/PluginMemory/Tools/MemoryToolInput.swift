import Foundation

enum MemoryToolInput {
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

    static func maxResults(_ value: Any?, default defaultValue: Int = 5, upperBound: Int = 20) -> Int {
        let requested = value as? Int ?? defaultValue
        return min(max(requested, 0), upperBound)
    }
}
