import XCTest
import SwiftData
import KitMail
@testable import PluginMail

final class MailCacheServiceTests: XCTestCase {
    private var service: MailCacheService!
    private var dbURL: URL!

    override func setUp() {
        super.setUp()
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MailCacheTests-\(UUID().uuidString)", isDirectory: true)
        dbURL = dir
        service = MailCacheService(databaseDirectory: dir)
    }

    override func tearDown() {
        service = nil
        try? FileManager.default.removeItem(at: dbURL)
        super.tearDown()
    }

    private let accountID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!

    private func summary(uid: UInt64, folder: String = "INBOX", subject: String = "", isRead: Bool = false) -> MailMessageSummary {
        MailMessageSummary(
            accountID: accountID,
            folder: folder,
            uid: uid,
            subject: subject,
            from: MailAddress(displayName: "Alice", email: "alice@example.com"),
            date: Date(timeIntervalSince1970: TimeInterval(uid)),
            isRead: isRead
        )
    }

    func testUpsertAndLastUID() async throws {
        try await service.upsertMessages([summary(uid: 1), summary(uid: 2), summary(uid: 5)], accountID: accountID, folder: "INBOX")
        let last = try await service.lastUID(accountID: accountID, folder: "INBOX")
        XCTAssertEqual(last, 5)
    }

    func testContainsAndOverwrite() async throws {
        try await service.upsertMessages([summary(uid: 1)], accountID: accountID, folder: "INBOX")
        let c1 = try await service.contains(accountID: accountID, folder: "INBOX", uid: 1)
        XCTAssertTrue(c1)
        let c2 = try await service.contains(accountID: accountID, folder: "INBOX", uid: 2)
        XCTAssertFalse(c2)

        // 同 uid 覆盖（未读变化）
        try await service.upsertMessages([summary(uid: 1, isRead: true)], accountID: accountID, folder: "INBOX")
        let items = try await service.messages(accountID: accountID, folder: "INBOX")
        XCTAssertEqual(items.count, 1)
        XCTAssertTrue(items[0].isRead)
    }

    func testUnreadCounts() async throws {
        try await service.upsertMessages(
            [summary(uid: 1), summary(uid: 2, isRead: true), summary(uid: 3)],
            accountID: accountID,
            folder: "INBOX"
        )
        try await service.upsertMessages([summary(uid: 9, folder: "Sent")], accountID: accountID, folder: "Sent")
        let unread = try await service.unreadCount(accountID: accountID, folder: "INBOX")
        XCTAssertEqual(unread, 2)
        let total = try await service.totalUnreadCount(accountID: accountID)
        XCTAssertEqual(total, 3)
    }

    func testRemoveKeepingAndPurge() async throws {
        try await service.upsertMessages([summary(uid: 1), summary(uid: 2), summary(uid: 3)], accountID: accountID, folder: "INBOX")
        let removed = try await service.removeMessages(accountID: accountID, folder: "INBOX", keeping: [2, 3])
        XCTAssertEqual(removed, 1)
        let stillThere = try await service.contains(accountID: accountID, folder: "INBOX", uid: 1)
        XCTAssertFalse(stillThere)

        try await service.purge(accountID: accountID)
        let afterPurge = try await service.messages(accountID: accountID, folder: "INBOX").count
        XCTAssertEqual(afterPurge, 0)
    }

    func testSearchMatchesSubjectAndFrom() async throws {
        try await service.upsertMessages(
            [
                summary(uid: 1, subject: "Meeting notes"),
                summary(uid: 2, subject: "Invoice"),
            ],
            accountID: accountID,
            folder: "INBOX"
        )
        let hits = try await service.search(accountID: accountID, folder: "INBOX", query: "meeting")
        XCTAssertEqual(hits.map(\.uid), [1])
        let invoiceHits = try await service.search(accountID: accountID, folder: nil, query: "invoice").map(\.uid)
        XCTAssertEqual(invoiceHits, [2])
    }
}

final class MailSyncServiceTests: XCTestCase {
    private var cache: MailCacheService!
    private var dbURL: URL!

    override func setUp() {
        super.setUp()
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MailSyncTests-\(UUID().uuidString)", isDirectory: true)
        dbURL = dir
        cache = MailCacheService(databaseDirectory: dir)
    }

    override func tearDown() {
        cache = nil
        try? FileManager.default.removeItem(at: dbURL)
        super.tearDown()
    }

    private let accountID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!

    private func summary(uid: UInt64, folder: String = "INBOX", isRead: Bool = false) -> MailMessageSummary {
        MailMessageSummary(
            accountID: accountID,
            folder: folder,
            uid: uid,
            subject: "Subj \(uid)",
            from: MailAddress(displayName: nil, email: "a@b.com"),
            date: Date(timeIntervalSince1970: TimeInterval(uid)),
            isRead: isRead
        )
    }

    func testIncrementalSyncInsertsNewOnly() async throws {
        let session = MockMailSession(messages: [summary(uid: 1), summary(uid: 2)])
        let sync = MailSyncService(session: session, cache: cache)

        let first = try await sync.syncFolder("INBOX", accountID: accountID)
        XCTAssertEqual(first.inserted, 2)
        XCTAssertEqual(first.updated, 0)
        let firstCount = try await cache.messages(accountID: accountID, folder: "INBOX").count
        XCTAssertEqual(firstCount, 2)

        // 服务器新增 uid 3、4 → 增量拉取
        await session.updateMessages([summary(uid: 1), summary(uid: 2), summary(uid: 3), summary(uid: 4)])
        let second = try await sync.syncFolder("INBOX", accountID: accountID)
        XCTAssertEqual(second.inserted, 2, "增量模式只统计游标后的新增")
        let secondCount = try await cache.messages(accountID: accountID, folder: "INBOX").count
        XCTAssertEqual(secondCount, 4)
    }

    func testIncrementalSyncSkipsAlreadyCached() async throws {
        let session = MockMailSession(messages: [summary(uid: 1), summary(uid: 2)])
        let sync = MailSyncService(session: session, cache: cache)
        _ = try await sync.syncFolder("INBOX", accountID: accountID)

        // 同 uid 已读变化（未读覆盖场景）：增量只拉游标后的新邮件，
        // flags 收敛需全量同步。
        await session.updateMessages([summary(uid: 1, isRead: true), summary(uid: 2)])
        let second = try await sync.syncFolder("INBOX", accountID: accountID, fullSync: true)
        XCTAssertEqual(second.inserted, 0)
        XCTAssertEqual(second.updated, 2, "全量同步重拉两条，均为覆盖更新")
        let items = try await cache.messages(accountID: accountID, folder: "INBOX")
        let readFlag = items[0].isRead
        XCTAssertTrue(readFlag, "远端未读变化应覆盖本地")
    }

    func testFullSyncRemovesDeleted() async throws {
        let session = MockMailSession(messages: [summary(uid: 1), summary(uid: 2), summary(uid: 3)])
        let sync = MailSyncService(session: session, cache: cache)
        _ = try await sync.syncFolder("INBOX", accountID: accountID, fullSync: true)

        // 服务器删除 uid 2 → 全量同步清理
        await session.updateMessages([summary(uid: 1), summary(uid: 3)])
        let second = try await sync.syncFolder("INBOX", accountID: accountID, fullSync: true)
        XCTAssertEqual(second.removed, 1)
        let uids = try await cache.messages(accountID: accountID, folder: "INBOX").map(\.uid)
        XCTAssertEqual(uids, [1, 3])
    }

    func testIncrementalSyncDoesNotDelete() async throws {
        let session = MockMailSession(messages: [summary(uid: 1), summary(uid: 2)])
        let sync = MailSyncService(session: session, cache: cache)
        _ = try await sync.syncFolder("INBOX", accountID: accountID)

        await session.updateMessages([summary(uid: 1), summary(uid: 2), summary(uid: 5)])
        _ = try await sync.syncFolder("INBOX", accountID: accountID)
        // 增量不清理旧 uid 2（即使远端仍存在）
        let count3 = try await cache.messages(accountID: accountID, folder: "INBOX").count
        XCTAssertEqual(count3, 3)
    }

    func testSyncMultipleFolders() async throws {
        let session = MockMailSession(messages: [
            summary(uid: 1, folder: "INBOX"),
            summary(uid: 7, folder: "Sent"),
        ])
        let sync = MailSyncService(session: session, cache: cache)
        let stats = try await sync.syncFolders(["INBOX", "Sent"], accountID: accountID)
        XCTAssertEqual(stats["INBOX"]?.inserted, 1)
        XCTAssertEqual(stats["Sent"]?.inserted, 1)
    }
}
