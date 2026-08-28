import Foundation
import Testing
@testable import KitAgentTool

struct AgentPendingImageAttachmentTests {
    @Test
    func idReturnsEmbeddedIdentifier() {
        let id = UUID()
        let attachment = AgentPendingImageAttachment.image(
            id: id, data: Data([0x01]), mimeType: "image/png", url: URL(fileURLWithPath: "/tmp/a.png")
        )
        #expect(attachment.id == id)
    }

    @Test
    func equalityComparesIdMimeTypeAndData() {
        let id = UUID()
        let data = Data([0x01, 0x02])
        let a = AgentPendingImageAttachment.image(
            id: id, data: data, mimeType: "image/png", url: URL(fileURLWithPath: "/tmp/a.png")
        )
        let b = AgentPendingImageAttachment.image(
            id: id, data: data, mimeType: "image/png", url: URL(fileURLWithPath: "/tmp/b.png")
        )
        // url 刻意不参与比较（同一张图可能同时来自文件与内存）
        #expect(a == b)
    }

    @Test
    func equalityFailsOnDifferentData() {
        let id = UUID()
        let a = AgentPendingImageAttachment.image(
            id: id, data: Data([0x01]), mimeType: "image/png", url: URL(fileURLWithPath: "/tmp/a.png")
        )
        let b = AgentPendingImageAttachment.image(
            id: id, data: Data([0x02]), mimeType: "image/png", url: URL(fileURLWithPath: "/tmp/a.png")
        )
        #expect(a != b)
    }

    @Test
    func equalityFailsOnDifferentMimeType() {
        let id = UUID()
        let a = AgentPendingImageAttachment.image(
            id: id, data: Data([0x01]), mimeType: "image/png", url: URL(fileURLWithPath: "/tmp/a.png")
        )
        let b = AgentPendingImageAttachment.image(
            id: id, data: Data([0x01]), mimeType: "image/jpeg", url: URL(fileURLWithPath: "/tmp/a.png")
        )
        #expect(a != b)
    }

    @Test
    func equalityFailsOnDifferentId() {
        let a = AgentPendingImageAttachment.image(
            id: UUID(), data: Data([0x01]), mimeType: "image/png", url: URL(fileURLWithPath: "/tmp/a.png")
        )
        let b = AgentPendingImageAttachment.image(
            id: UUID(), data: Data([0x01]), mimeType: "image/png", url: URL(fileURLWithPath: "/tmp/a.png")
        )
        #expect(a != b)
    }
}
