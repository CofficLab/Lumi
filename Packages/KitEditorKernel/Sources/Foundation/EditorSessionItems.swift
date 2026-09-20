import Foundation

public struct EditorOpenEditorItem: Identifiable, Equatable {
    public let sessionID: UUID
    public let fileURL: URL?
    public let title: String
    public let isDirty: Bool
    public let isPinned: Bool
    public let isActive: Bool
    public let recentActivationRank: Int?

    public var id: UUID { sessionID }

    public init(
        sessionID: UUID,
        fileURL: URL?,
        title: String,
        isDirty: Bool,
        isPinned: Bool,
        isActive: Bool,
        recentActivationRank: Int?
    ) {
        self.sessionID = sessionID
        self.fileURL = fileURL
        self.title = title
        self.isDirty = isDirty
        self.isPinned = isPinned
        self.isActive = isActive
        self.recentActivationRank = recentActivationRank
    }
}

public struct EditorTab: Identifiable, Equatable {
    public let sessionID: UUID
    public var fileURL: URL?
    public var title: String
    public var isDirty: Bool
    public var isPinned: Bool
    public var isPreview: Bool

    public var id: UUID { sessionID }

    public init(
        sessionID: UUID,
        fileURL: URL?,
        title: String? = nil,
        isDirty: Bool = false,
        isPinned: Bool = false,
        isPreview: Bool = false
    ) {
        self.sessionID = sessionID
        self.fileURL = fileURL
        self.title = title ?? fileURL?.lastPathComponent ?? "Untitled"
        self.isDirty = isDirty
        self.isPinned = isPinned
        self.isPreview = isPreview
    }
}

public struct EditorNavigationTarget: Equatable {
    public let sessionID: UUID
    public let fileURL: URL?
    public let title: String
    public let isDirty: Bool
    public let isPinned: Bool

    public init(
        sessionID: UUID,
        fileURL: URL?,
        title: String,
        isDirty: Bool,
        isPinned: Bool
    ) {
        self.sessionID = sessionID
        self.fileURL = fileURL
        self.title = title
        self.isDirty = isDirty
        self.isPinned = isPinned
    }
}
