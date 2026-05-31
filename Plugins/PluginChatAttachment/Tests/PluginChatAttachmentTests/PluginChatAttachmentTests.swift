import Foundation
import Testing
@testable import PluginChatAttachment

@Test func packageLoads() async throws {
    #expect(Bool(true))
}

@Test func droppedFileURLStringsBecomeFileURLs() {
    #expect(ChatAttachmentDropRules.fileURL(fromDroppedString: "/tmp/a.png")?.path == "/tmp/a.png")
    #expect(ChatAttachmentDropRules.fileURL(fromDroppedString: " file:///tmp/a%20b.png\n")?.path == "/tmp/a b.png")
    #expect(ChatAttachmentDropRules.fileURL(fromDroppedString: "https://example.com/a.png") == nil)
    #expect(ChatAttachmentDropRules.fileURL(fromDroppedString: "relative/a.png") == nil)
}

@Test func imageFileDetectionIsCaseInsensitive() {
    #expect(ChatAttachmentDropRules.isChatImageFileURL(URL(fileURLWithPath: "/tmp/a.PNG")))
    #expect(ChatAttachmentDropRules.isChatImageFileURL(URL(fileURLWithPath: "/tmp/a.heic")))
    #expect(!ChatAttachmentDropRules.isChatImageFileURL(URL(fileURLWithPath: "/tmp/a.txt")))
}
