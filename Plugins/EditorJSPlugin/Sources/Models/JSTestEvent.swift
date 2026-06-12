import Foundation

public struct JSTestEvent: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let file: String?
    public let line: Int?
    public let status: Status
    public let duration: TimeInterval?
    public let message: String?

    public enum Status: String, Sendable {
        case passed
        case failed
        case skipped
        case running
    }
}
