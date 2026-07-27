import Foundation

@MainActor
public protocol LumiAskUserResuming: AnyObject {
    func resumeAfterAskUser(conversationID: UUID, toolCallID: String, answer: String) async
}
