import Foundation

public struct IdleActivityEvent: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let timestamp: Date
    public let kind: IdleActivityKind

    public init(id: UUID = UUID(), timestamp: Date, kind: IdleActivityKind) {
        self.id = id
        self.timestamp = timestamp
        self.kind = kind
    }
}

public enum IdleActivityKind: String, Codable, Sendable, CaseIterable {
    case appBecameActive
    case editorInput
    case fileSave
    case terminalCommandStarted
    case agentMessageSent
    case projectChanged

    public var inferenceWeight: Double {
        switch self {
        case .editorInput, .agentMessageSent:
            return 3.0
        case .fileSave, .terminalCommandStarted:
            return 2.0
        case .projectChanged:
            return 1.5
        case .appBecameActive:
            return 1.0
        }
    }

    public var throttleInterval: TimeInterval {
        switch self {
        case .editorInput:
            return 60
        case .appBecameActive:
            return 300
        case .fileSave:
            return 30
        case .terminalCommandStarted:
            return 60
        case .agentMessageSent:
            return 15
        case .projectChanged:
            return 60
        }
    }
}
