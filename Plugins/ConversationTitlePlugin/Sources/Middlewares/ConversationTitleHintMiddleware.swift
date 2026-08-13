import Foundation
import KernelLumi

extension ConversationTitlePlugin {
    @MainActor
    public static func sendMiddlewares(lumiCore: Any) -> [LumiChatMessage] {
        []
    }
}
