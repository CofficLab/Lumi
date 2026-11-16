import Foundation
import ProviderConversation
import ProviderMessage
import Testing
@testable import PluginMessageSender

/// 锁定 #517：附件编码途中用户新增附件时，提交后只移除「已送出的那一份」，
/// 后来加入的附件保留在挂起池，不会被下一条消息重复带上。
///
/// 旧实现要求挂起池与送出快照「完全相等」才清空，`[X,Y] != [X]` 时连已送出的
/// X 也留在池里。这里的用例都在提交那一刻让池处于 `[X,Y]`，精确复现该窗口。
@Suite("MessageSender 已送出附件的精确清理")
@MainActor
struct MessageSenderSentAttachmentPoolTests {

    @Test("编码途中新增图片时，已送出的图片被精确移除、后来者保留")
    func sentImageRemovedWhenAnotherAddedDuringEncode() throws {
        let fixture = SenderFixture()
        let conversationID = try fixture.conversations.createConversation(
            title: nil, projectPath: nil, providerID: nil, modelName: nil
        )
        let sent = UserImageAttachment.fixture()
        let addedLater = UserImageAttachment.fixture()

        // 发送入口在编码前抓取快照 [sent]；编码途中用户又加入 addedLater，
        // 因此提交那一刻挂起池已是 [sent, addedLater]。
        fixture.sender.addImageAttachment(sent)
        fixture.sender.addImageAttachment(addedLater)

        let result = try fixture.sender.commitUserMessage(
            "hi",
            imageAttachments: [sent],
            fileAttachments: [],
            conversationID: conversationID
        )

        let commit = try #require(result)
        #expect(commit.wasQueued == false)
        let userMessageID = try #require(commit.userMessageID)
        let message = try #require(fixture.messages.message(id: userMessageID, in: conversationID))
        // 第一条消息正确带上 sent。
        #expect(UserAttachmentMetadata.decodeImageAttachments(from: message.metadata) == [sent])
        // 池里只剩后来加入的 addedLater，sent 不得残留导致重复发送。
        #expect(fixture.sender.pendingImageAttachments == [addedLater])
    }

    @Test("编码途中新增文件时，已送出的文件被精确移除、后来者保留")
    func sentFileRemovedWhenAnotherAddedDuringEncode() throws {
        let fixture = SenderFixture()
        let conversationID = try fixture.conversations.createConversation(
            title: nil, projectPath: nil, providerID: nil, modelName: nil
        )
        let sent = UserFileAttachment.fixture(fileName: "sent.txt")
        let addedLater = UserFileAttachment.fixture(fileName: "later.txt")

        fixture.sender.addFileAttachment(sent)
        fixture.sender.addFileAttachment(addedLater)

        let result = try fixture.sender.commitUserMessage(
            "hi",
            imageAttachments: [],
            fileAttachments: [sent],
            conversationID: conversationID
        )

        let commit = try #require(result)
        let userMessageID = try #require(commit.userMessageID)
        let message = try #require(fixture.messages.message(id: userMessageID, in: conversationID))
        #expect(UserAttachmentMetadata.decodeFileAttachments(from: message.metadata) == [sent])
        #expect(fixture.sender.pendingFileAttachments == [addedLater])
    }

    @Test("后台编码窗口内新增的附件，在异步提交后仍保留")
    func laterAddedImageSurvivesBackgroundCommit() async throws {
        let fixture = SenderFixture()
        let conversationID = try fixture.conversations.createConversation(
            title: nil, projectPath: nil, providerID: nil, modelName: nil
        )
        let sent = UserImageAttachment.fixture()
        let addedLater = UserImageAttachment.fixture()
        fixture.sender.addImageAttachment(sent)

        // Task 体在主 actor 让出前不会执行；下面的新增模拟「编码途中加入」。
        let task = Task { @MainActor in
            try await fixture.sender.commitUserMessageInBackground(
                "hi",
                imageAttachments: [sent],
                fileAttachments: [],
                conversationID: conversationID
            )
        }
        fixture.sender.addImageAttachment(addedLater)

        let result = try await task.value
        let commit = try #require(result)
        let userMessageID = try #require(commit.userMessageID)
        let message = try #require(fixture.messages.message(id: userMessageID, in: conversationID))
        #expect(UserAttachmentMetadata.decodeImageAttachments(from: message.metadata) == [sent])
        #expect(fixture.sender.pendingImageAttachments == [addedLater])
    }

    @Test("池未被改动时送出快照被整体清空（正常路径不变）")
    func unchangedPoolIsFullyCleared() throws {
        let fixture = SenderFixture()
        let conversationID = try fixture.conversations.createConversation(
            title: nil, projectPath: nil, providerID: nil, modelName: nil
        )
        let image = UserImageAttachment.fixture()
        let file = UserFileAttachment.fixture()
        fixture.sender.addImageAttachment(image)
        fixture.sender.addFileAttachment(file)

        _ = try fixture.sender.commitUserMessage(
            "hi",
            imageAttachments: [image],
            fileAttachments: [file],
            conversationID: conversationID
        )

        #expect(fixture.sender.pendingImageAttachments.isEmpty)
        #expect(fixture.sender.pendingFileAttachments.isEmpty)
    }

    @Test("送出的附件已被用户手动移除时不再重复广播变化")
    func alreadyRemovedSentAttachmentDoesNotNotify() throws {
        let fixture = SenderFixture()
        let conversationID = try fixture.conversations.createConversation(
            title: nil, projectPath: nil, providerID: nil, modelName: nil
        )
        let sent = UserImageAttachment.fixture()
        let addedLater = UserImageAttachment.fixture()
        fixture.sender.addImageAttachment(sent)
        fixture.sender.addImageAttachment(addedLater)
        // 用户在编码途中手动撤掉了 sent，池里只剩 addedLater。
        fixture.sender.removeImageAttachment(id: sent.id)

        var attachmentEvents = 0
        let observer = fixture.sender.addMessageSenderObserver { event in
            if case .attachmentsChanged = event { attachmentEvents += 1 }
        }
        defer { observer.cancel() }

        _ = try fixture.sender.commitUserMessage(
            "hi",
            imageAttachments: [sent],
            fileAttachments: [],
            conversationID: conversationID
        )

        // sent 已不在池中，清理是 no-op：池保持 [addedLater]，不广播多余变化。
        #expect(fixture.sender.pendingImageAttachments == [addedLater])
        #expect(attachmentEvents == 0)
    }
}