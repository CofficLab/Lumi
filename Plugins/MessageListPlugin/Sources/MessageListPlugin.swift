import LumiKernel
import LumiUI
import SwiftUI

@MainActor
public final class MessageListPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.chat-messages-section"
    public let name = "Chat Messages"
    public let order = 82
    public static let policy: LumiPluginPolicy = .alwaysOn

    public init() {}

    public func register(kernel: LumiKernel) throws {
        // Register services here
    }

    public func boot(kernel: LumiKernel) async throws {}

    public func chatSectionItems(kernel: LumiKernel) -> [ChatSectionItem] {
        guard let coordinator = kernel.resolveService(ChatSectionCoordinator.self) else {
            return [
                ChatSectionItem(
                    id: id,
                    placement: .stack,
                    fillsRemainingHeight: true,
                    showsTrailingDivider: false
                ) {
                    ChatMessagesErrorView(pluginName: name)
                }
            ]
        }

        return [
            ChatSectionItem(
                id: id,
                placement: .stack,
                fillsRemainingHeight: true,
                showsTrailingDivider: false
            ) {
                ChatMessagesSectionView(coordinator: coordinator)
            }
        ]
    }
}
