import Foundation

public enum ViewMode: String, CaseIterable, Identifiable {
    case messages
    case conversations

    public var id: String { rawValue }
}
