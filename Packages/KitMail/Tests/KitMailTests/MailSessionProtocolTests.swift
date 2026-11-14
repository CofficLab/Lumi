import XCTest
import MailCore
@testable import KitMail

final class MailSessionProtocolTests: XCTestCase {
    func testModuleExportsSessionProtocols() {
        // 协议类型的元类型存在即证明导出可用（编译期验证）
        let factory: any MailSessionFactory.Type = MailCoreAdapterFactory.self
        _ = factory
        let session: any MailSessionServing.Type = MockMailSession.self
        _ = session
    }

    func testMockSessionFullFlow() async throws {
        let session = MockMailSession()
        try await session.connect()

        let folders = try await session.listFolders()
        XCTAssertEqual(folders.count, 2)
        XCTAssertEqual(folders[0].kind, .inbox)

        let messages = try await session.fetchMessages(folder: "INBOX", sinceUID: nil, limit: 3)
        XCTAssertEqual(messages.count, 3)
        XCTAssertEqual(messages.last?.uid, 5)

        let detail = try await session.fetchBody(uid: 2, folder: "INBOX")
        XCTAssertEqual(detail.plainTextBody, "Body 2")
        XCTAssertEqual(detail.summary.subject, "Message 2")

        let uids = try await session.search(query: "Message 3", folder: "INBOX")
        XCTAssertEqual(uids, [3])

        try await session.sendMessage(mime: Data("x".utf8))
        try await session.appendMessage(mime: Data("d".utf8), folder: "Drafts", isDraft: true)
    }

    func testMockSessionAuthFailure() async {
        let session = MockMailSession()
        session.failConnect = true
        do {
            try await session.connect()
            XCTFail("expected authFailed")
        } catch let error as MailError {
            XCTAssertEqual(error, .authFailed)
        } catch {
            XCTFail("unexpected error \(error)")
        }
    }

    func testMockSessionFetchFailure() async {
        let session = MockMailSession()
        session.failFetch = true
        do {
            _ = try await session.fetchMessages(folder: "INBOX", sinceUID: nil, limit: 10)
            XCTFail("expected network")
        } catch let error as MailError {
            XCTAssertEqual(error, .network)
        } catch {
            XCTFail("unexpected error \(error)")
        }
    }

    func testMockSessionNotFound() async {
        let session = MockMailSession()
        do {
            _ = try await session.fetchBody(uid: 999, folder: "INBOX")
            XCTFail("expected notFound")
        } catch let error as MailError {
            XCTAssertEqual(error, .notFound)
        } catch {
            XCTFail("unexpected error \(error)")
        }
    }
}

final class MailCoreAdapterErrorMappingTests: XCTestCase {
    func testMapsAuthError() {
        let nsError = NSError(domain: MCOErrorDomain, code: MCOErrorCode.authentication.rawValue)
        XCTAssertEqual(MailCoreAdapter.mapError(nsError), .authFailed)
        let gmailAppPassword = NSError(
            domain: MCOErrorDomain,
            code: MCOErrorCode.gmailApplicationSpecificPasswordRequired.rawValue
        )
        XCTAssertEqual(MailCoreAdapter.mapError(gmailAppPassword), .authFailed)
    }

    func testMapsNetworkErrors() {
        let connection = NSError(domain: MCOErrorDomain, code: MCOErrorCode.connection.rawValue)
        XCTAssertEqual(MailCoreAdapter.mapError(connection), .network)
        let tls = NSError(domain: MCOErrorDomain, code: MCOErrorCode.tlsNotAvailable.rawValue)
        XCTAssertEqual(MailCoreAdapter.mapError(tls), .network)
        let cert = NSError(domain: MCOErrorDomain, code: MCOErrorCode.certificate.rawValue)
        XCTAssertEqual(MailCoreAdapter.mapError(cert), .network)
    }

    func testMapsNotFound() {
        let nsError = NSError(domain: MCOErrorDomain, code: MCOErrorCode.nonExistantFolder.rawValue)
        XCTAssertEqual(MailCoreAdapter.mapError(nsError), .notFound)
    }

    func testMapsUnknownToProtocol() {
        let nsError = NSError(domain: MCOErrorDomain, code: MCOErrorCode.store.rawValue)
        if case .protocolError = MailCoreAdapter.mapError(nsError) {
            // 期望协议错误
        } else {
            XCTFail("expected protocolError, got \(MailCoreAdapter.mapError(nsError))")
        }
    }

    func testMapsForeignDomainToProtocol() {
        let nsError = NSError(domain: "OtherDomain", code: 42)
        if case .protocolError = MailCoreAdapter.mapError(nsError) {
            // 期望协议错误
        } else {
            XCTFail("expected protocolError, got \(MailCoreAdapter.mapError(nsError))")
        }
    }
}

/// 回归 #727：文件夹列表必须走 IMAP LIST（全部），而不是 LSUB（已订阅）。
final class MailCoreAdapterFolderOperationTests: XCTestCase {
    func testFolderListingRequestsAllFoldersNotSubscribed() {
        let session = FolderOperationSpySession()
        _ = MailCoreAdapter.fetchFoldersOperation(using: session)
        XCTAssertEqual(session.allFoldersCallCount, 1, "应请求全部文件夹")
        XCTAssertEqual(session.subscribedFoldersCallCount, 0, "不应按订阅状态过滤")
    }
}

/// 记录调用了哪种文件夹操作；返回 nil 使调用方走既有错误分支。
private final class FolderOperationSpySession: MCOIMAPSession {
    private(set) var allFoldersCallCount = 0
    private(set) var subscribedFoldersCallCount = 0

    override func fetchAllFoldersOperation() -> MCOIMAPFetchFoldersOperation! {
        allFoldersCallCount += 1
        return nil
    }

    override func fetchSubscribedFoldersOperation() -> MCOIMAPFetchFoldersOperation! {
        subscribedFoldersCallCount += 1
        return nil
    }
}

/// 回归 #403：已发送归档必须用 `\Seen`，草稿用 `\Draft`；Sent 副本不得带 `\Draft`。
final class MailCoreAdapterAppendFlagsTests: XCTestCase {
    func testSentAppendUsesSeenWithoutDraft() {
        let session = AppendOperationSpySession()
        _ = MailCoreAdapter.appendMessageOperation(
            using: session, folder: "Sent", mime: Data("m".utf8), isDraft: false
        )
        XCTAssertEqual(session.recordedFlags, .seen, "已发送归档应标记为已读")
        XCTAssertFalse(session.recordedFlags.contains(.draft), "已发送副本不得带 \\Draft")
    }

    func testDraftAppendUsesDraftFlag() {
        let session = AppendOperationSpySession()
        _ = MailCoreAdapter.appendMessageOperation(
            using: session, folder: "Drafts", mime: Data("m".utf8), isDraft: true
        )
        XCTAssertEqual(session.recordedFlags, .draft, "草稿应标记为 \\Draft")
    }
}

/// 记录 APPEND 请求的标记；返回 nil 使调用方走既有错误分支。
private final class AppendOperationSpySession: MCOIMAPSession {
    private(set) var recordedFlags: MCOMessageFlag = []

    override func appendMessageOperation(
        withFolder folder: String,
        messageData: Data,
        flags: MCOMessageFlag
    ) -> MCOIMAPAppendMessageOperation! {
        recordedFlags = flags
        return nil
    }
}
