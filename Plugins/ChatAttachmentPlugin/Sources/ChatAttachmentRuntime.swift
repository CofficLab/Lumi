import AgentToolKit
import Foundation

@MainActor
public enum ChatAttachmentRuntime {
    public static var pendingAttachmentsProvider: () -> [AgentPendingImageAttachment] = { [] }
    public static var removeAttachment: (UUID) -> Void = { _ in }
    public static var handleImageUpload: (URL) -> Void = { _ in }
    public static var handleScreenshotData: (Data) -> Void = { _ in }
    public static var appendDraftText: (String) -> Void = { _ in }
    public static var canChatProvider: () -> Bool = { false }

    public static var pendingAttachments: [AgentPendingImageAttachment] {
        pendingAttachmentsProvider()
    }

    public static var canChat: Bool {
        canChatProvider()
    }
}
