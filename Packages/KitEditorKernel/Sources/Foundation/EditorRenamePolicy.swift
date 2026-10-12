import Foundation

public enum EditorRenamePolicy {
    public static func normalizedProposedName(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    public static func completedMessage(prefix: String, changedFiles: Int) -> String {
        "\(prefix) \(changedFiles)"
    }
}
