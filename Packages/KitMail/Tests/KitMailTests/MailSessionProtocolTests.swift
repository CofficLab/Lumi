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
        try await session.appendDraft(mime: Data("d".utf8), folder: "Drafts")
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
