import Foundation
import Testing
import AgentToolKit
import LumiCoreKit
@testable import PluginChatAttachment

@Test func packageLoads() async throws {
    #expect(Bool(true))
}

@Test func droppedFileURLStringsBecomeFileURLs() {
    #expect(ChatAttachmentDropRules.fileURL(fromDroppedString: "/tmp/a.png")?.path == "/tmp/a.png")
    #expect(ChatAttachmentDropRules.fileURL(fromDroppedString: " file:///tmp/a%20b.png\n")?.path == "/tmp/a b.png")
    #expect(ChatAttachmentDropRules.fileURL(fromDroppedString: "~/Desktop/a.png")?.path == FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop/a.png").path)
    #expect(ChatAttachmentDropRules.fileURL(fromDroppedString: "https://example.com/a.png") == nil)
    #expect(ChatAttachmentDropRules.fileURL(fromDroppedString: "relative/a.png") == nil)
}

@Test func multilineDroppedFileURLStringsBecomeFileURLs() {
    let urls = ChatAttachmentDropRules.fileURLs(fromDroppedString: "file:///tmp/a%201.png\n/tmp/b.png\nrelative/c.png")

    #expect(urls.map(\.path) == ["/tmp/a 1.png", "/tmp/b.png"])
}

@Test func imageFileDetectionIsCaseInsensitive() {
    #expect(ChatAttachmentDropRules.isChatImageFileURL(URL(fileURLWithPath: "/tmp/a.PNG")))
    #expect(ChatAttachmentDropRules.isChatImageFileURL(URL(fileURLWithPath: "/tmp/a.heic")))
    #expect(!ChatAttachmentDropRules.isChatImageFileURL(URL(fileURLWithPath: "/tmp/a.txt")))
}

@MainActor
@Test func windowConversationVMProvidesAndMutatesPendingAttachments() {
    let conversationId = UUID()
    let attachmentId = UUID()
    let attachment = AgentPendingImageAttachment.image(
        id: attachmentId,
        data: Data([1, 2, 3]),
        mimeType: "image/png",
        url: URL(fileURLWithPath: "/tmp/a.png")
    )
    let imageURL = URL(fileURLWithPath: "/tmp/upload.png")
    let screenshotData = Data([4, 5, 6])
    var removedAttachmentIds: [UUID] = []
    var uploadedImageURLs: [URL] = []
    var screenshotPayloads: [Data] = []
    var appendedDrafts: [String] = []

    let conversationVM = WindowConversationVM(
        selectedConversationId: conversationId,
        pendingAttachmentsProvider: { [attachment] in [attachment] },
        attachmentRemover: { attachmentId in
            removedAttachmentIds.append(attachmentId)
        },
        imageUploadHandler: { url in
            uploadedImageURLs.append(url)
        },
        screenshotDataHandler: { data in
            screenshotPayloads.append(data)
        },
        draftTextAppender: { text in
            appendedDrafts.append(text)
        }
    )

    #expect(conversationVM.canAttachToCurrentConversation)
    #expect(conversationVM.pendingAttachments == [attachment])

    conversationVM.removeAttachment(id: attachmentId)
    conversationVM.handleImageUpload(url: imageURL)
    conversationVM.handleScreenshotData(screenshotData)
    conversationVM.appendDraftText("/tmp/file.txt")

    #expect(removedAttachmentIds == [attachmentId])
    #expect(uploadedImageURLs == [imageURL])
    #expect(screenshotPayloads == [screenshotData])
    #expect(appendedDrafts == ["/tmp/file.txt"])

    let version = conversationVM.attachmentVersion
    conversationVM.notifyAttachmentsChanged()
    #expect(conversationVM.attachmentVersion == version + 1)

    conversationVM.selectedConversationId = nil
    #expect(!conversationVM.canAttachToCurrentConversation)
}
