import LumiCoreChat
import LumiKernel
import SwiftUI

@MainActor
public final class ChatPendingSectionPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.chat-pending-section"
    public let name = "Chat Pending Messages"
    public let order = 95
    public let policy: LumiPluginPolicy = .alwaysOn

    public init() {}
    public func register(kernel: LumiKernel) throws {}
    public func boot(kernel: LumiKernel) async throws {}

    public func chatSectionItems(kernel: LumiKernel) -> [ChatSectionItem] {
        // Pending messages are now rendered inline inside ChatComposerSectionView
        []
    }
}

@MainActor
public final class ChatAttachmentSectionPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.chat-attachment-section"
    public let name = "Chat Attachment"
    public let order = 94
    public let policy: LumiPluginPolicy = .alwaysOn

    public init() {}
    public func register(kernel: LumiKernel) throws {}
    public func boot(kernel: LumiKernel) async throws {}

    public func chatSectionItems(kernel: LumiKernel) -> [ChatSectionItem] {
        guard let coordinator = kernel.resolveService(ChatSectionCoordinator.self) else {
            return []
        }

        return [
            ChatSectionItem(id: id, placement: .stack) {
                ChatAttachmentSectionView(coordinator: coordinator)
            }
        ]
    }
}

@MainActor
public final class ChatComposerSectionPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.chat-composer-section"
    public let name = "Chat Composer"
    public let order = 96
    public let policy: LumiPluginPolicy = .alwaysOn

    public init() {}
    public func register(kernel: LumiKernel) throws {}
    public func boot(kernel: LumiKernel) async throws {}

    public func chatSectionItems(kernel: LumiKernel) -> [ChatSectionItem] {
        guard let coordinator = kernel.resolveService(ChatSectionCoordinator.self) else {
            return []
        }

        return [
            ChatSectionItem(id: id, placement: .bottomFixed) {
                ChatComposerSectionView(coordinator: coordinator)
            }
        ]
    }
}
