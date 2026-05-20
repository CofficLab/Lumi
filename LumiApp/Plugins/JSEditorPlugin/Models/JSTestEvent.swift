import Foundation

struct JSTestEvent: Identifiable, Sendable {
    let id: String
    let name: String
    let file: String?
    let line: Int?
    let status: Status
    let duration: TimeInterval?
    let message: String?

    enum Status: String, Sendable {
        case passed
        case failed
        case skipped
        case running
    }
}
