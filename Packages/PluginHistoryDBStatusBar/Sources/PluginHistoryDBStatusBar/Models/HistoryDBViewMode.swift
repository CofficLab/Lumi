import Foundation

public enum HistoryDBViewMode: String, CaseIterable, Identifiable {
    case messages
    case conversations

    public var id: String { rawValue }
}
