import Foundation

public struct ToolExecutionSummary: Sendable, Equatable {
    public var hadUserRejection: Bool
    public var hasAwaitingUserResponse: Bool

    public init(
        hadUserRejection: Bool = false,
        hasAwaitingUserResponse: Bool = false
    ) {
        self.hadUserRejection = hadUserRejection
        self.hasAwaitingUserResponse = hasAwaitingUserResponse
    }
}
