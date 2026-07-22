import Foundation

@MainActor
public protocol ChatContributionProviding: AnyObject {
    func allLLMProviders() -> [any LumiLLMProvider]
    func allSendMiddlewares() -> [any LumiSendMiddleware]
    func allMessageRenderers() -> [LumiMessageRendererItem]
    func dispatchTurnFinished(conversationID: UUID, reason: LumiTurnEndReason) async
}
