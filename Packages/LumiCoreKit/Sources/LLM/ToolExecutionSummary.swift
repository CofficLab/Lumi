import Foundation

/// 工具批量执行结果摘要。
public struct ToolExecutionSummary: Sendable, Equatable {
    public var hadUserRejection: Bool
    public var hasAwaitingUserResponse: Bool

    public init(hadUserRejection: Bool = false, hasAwaitingUserResponse: Bool = false) {
        self.hadUserRejection = hadUserRejection
        self.hasAwaitingUserResponse = hasAwaitingUserResponse
    }
}
