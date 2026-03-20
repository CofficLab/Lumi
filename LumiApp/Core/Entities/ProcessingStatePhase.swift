import Foundation

enum ProcessingStatePhase: String, Sendable {
    case idle
    case sending
    case waitingFirstToken
    case generating
    case finishing
}
