import Foundation
import LumiKernel

extension ConversationTitlePlugin {
    @MainActor
    public static func sendMiddlewares(lumiCore: Any) -> [LumiChatMessage] {
        []
    }
}
