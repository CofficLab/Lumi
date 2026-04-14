import Foundation

enum HistoryDBViewMode: String, CaseIterable, Identifiable {
    case messages
    case conversations

    var id: String { rawValue }
}
