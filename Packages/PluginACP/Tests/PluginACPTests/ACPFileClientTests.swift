import Foundation
import XCTest
@testable import PluginACP
import ProviderACP

@MainActor
final class ACPFileClientTests: XCTestCase {
    private final class MockConversationFactory: ACPSessionCreating {
        func createConversation(
            title: String?,
            projectPath: String?,
            providerID: String?,
            modelName: String?
        ) throws -> UUID {
            UUID()
        }
    }

    /// 记录出站请求并自动回包。
    @MainActor
    private final class AutoClient {
        var requests: [(method: String, params: JSONValue?)] = []
        /// method → 结果载荷。
        var results: [String: JSONValue] = [:]
        var errorToThrow: ACPError?
        private var requester: ACPClientRequester!

        func makeRequester() -> ACPClientRequester {
            let requester = ACPClientRequester { [weak self] message in
                guard case .request(let id, let method, let params) = message else { return }
                self?.requests.append((method, params))
                if let error = self?.errorToThrow {
                    self?.requester.handleError(id: id, error: error)
                } else {
                    let result = self?.results[method]
                    self?.requester.handleResponse(id: id, result: result)
                }
            }
            self.requester = requester
            return requester
        }
    }

    private func capabilities(read: Bool, write: Bool) -> ACPClientCapabilitiesStore {
        let store = ACPClientCapabilitiesStore()
        store.update(from: ACPClientCapabilities(fs: ACPFSClientCapabilities(
            readTextFile: read,
            writeTextFile: write
        )))
        return store
    }

    // MARK: - 能力缺失

    func testReadWithoutCapabilityThrows() async throws {
        let sessions = ACPSessionManager(conversationFactory: MockConversationFactory())
        let sessionID = try sessions.createSession(cwd: "/tmp/project")
        let caps = capabilities(read: false, write: false)
        let requester = ACPClientRequester(onSend: { _ in })
        let client = ACPFileClient(requester: requester, capabilities: caps, sessions: sessions)

        do {
            _ = try await client.readTextFile(sessionID: sessionID, path: "/tmp/project/a.txt")
            XCTFail("未声明能力时不得调用")
        } catch let error as ACPFileClientError {
            guard case .capabilityUnavailable(let method) = error else {
                return XCTFail("期望 capabilityUnavailable，得到 \(error)")
            }
            XCTAssertEqual(method, ACPMethod.fsReadTextFile)
        }
    }

    func testWriteWithoutCapabilityThrows() async throws {
        let sessions = ACPSessionManager(conversationFactory: MockConversationFactory())
        let sessionID = try sessions.createSession(cwd: "/tmp/project")
        let caps = capabilities(read: true, write: false)
        let requester = ACPClientRequester(onSend: { _ in })
        let client = ACPFileClient(requester: requester, capabilities: caps, sessions: sessions)

        do {
            try await client.writeTextFile(sessionID: sessionID, path: "/tmp/project/a.txt", content: "x")
            XCTFail("未声明写能力时不得调用")
        } catch let error as ACPFileClientError {
            guard case .capabilityUnavailable = error else {
                return XCTFail("期望 capabilityUnavailable，得到 \(error)")
            }
        }
    }

    // MARK: - 读写

    func testReadSendsAbsolutePathAndReturnsContent() async throws {
        let sessions = ACPSessionManager(conversationFactory: MockConversationFactory())
        let sessionID = try sessions.createSession(cwd: "/tmp/project")
        let caps = capabilities(read: true, write: true)
        let auto = AutoClient()
        auto.results[ACPMethod.fsReadTextFile] = try JSONValue.stringify(
            ACPReadTextFileResult(content: "hello")
        )
        let client = ACPFileClient(
            requester: auto.makeRequester(),
            capabilities: caps,
            sessions: sessions
        )

        let content = try await client.readTextFile(
            sessionID: sessionID,
            path: "/tmp/project/sub/a.txt",
            line: 2,
            limit: 10
        )
        XCTAssertEqual(content, "hello")

        let request = try XCTUnwrap(auto.requests.first { $0.method == ACPMethod.fsReadTextFile })
        let params = try XCTUnwrap(try request.params?.decoded(as: ACPReadTextFileParams.self))
        XCTAssertEqual(params.path, "/tmp/project/sub/a.txt")
        XCTAssertEqual(params.line, 2)
        XCTAssertEqual(params.limit, 10)
    }

    func testWriteSendsContent() async throws {
        let sessions = ACPSessionManager(conversationFactory: MockConversationFactory())
        let sessionID = try sessions.createSession(cwd: "/tmp/project")
        let caps = capabilities(read: true, write: true)
        let auto = AutoClient()
        // fs/write_text_file 成功响应为 result: null。
        auto.results[ACPMethod.fsWriteTextFile] = .null
        let client = ACPFileClient(
            requester: auto.makeRequester(),
            capabilities: caps,
            sessions: sessions
        )

        try await client.writeTextFile(
            sessionID: sessionID,
            path: "/tmp/project/a.txt",
            content: "written"
        )
        let request = try XCTUnwrap(auto.requests.first { $0.method == ACPMethod.fsWriteTextFile })
        let params = try XCTUnwrap(try request.params?.decoded(as: ACPWriteTextFileParams.self))
        XCTAssertEqual(params.path, "/tmp/project/a.txt")
        XCTAssertEqual(params.content, "written")
    }

    // MARK: - 路径校验

    func testRelativePathRejected() async throws {
        let sessions = ACPSessionManager(conversationFactory: MockConversationFactory())
        let sessionID = try sessions.createSession(cwd: "/tmp/project")
        let client = ACPFileClient(
            requester: ACPClientRequester(onSend: { _ in }),
            capabilities: capabilities(read: true, write: true),
            sessions: sessions
        )
        do {
            _ = try await client.readTextFile(sessionID: sessionID, path: "relative/a.txt")
            XCTFail("相对路径应被拒绝")
        } catch let error as ACPFileClientError {
            guard case .pathNotAbsolute = error else {
                return XCTFail("期望 pathNotAbsolute，得到 \(error)")
            }
        }
    }

    func testPathOutsideWorkspaceRejected() async throws {
        let sessions = ACPSessionManager(conversationFactory: MockConversationFactory())
        let sessionID = try sessions.createSession(cwd: "/tmp/project")
        let client = ACPFileClient(
            requester: ACPClientRequester(onSend: { _ in }),
            capabilities: capabilities(read: true, write: true),
            sessions: sessions
        )
        do {
            _ = try await client.readTextFile(sessionID: sessionID, path: "/etc/passwd")
            XCTFail("越出工作目录的路径应被拒绝")
        } catch let error as ACPFileClientError {
            guard case .pathOutsideWorkspace = error else {
                return XCTFail("期望 pathOutsideWorkspace，得到 \(error)")
            }
        }
    }

    func testTraversalEscapeRejected() async throws {
        let sessions = ACPSessionManager(conversationFactory: MockConversationFactory())
        let sessionID = try sessions.createSession(cwd: "/tmp/project")
        let client = ACPFileClient(
            requester: ACPClientRequester(onSend: { _ in }),
            capabilities: capabilities(read: true, write: true),
            sessions: sessions
        )
        // 用 .. 逃逸必须被归一化后拦截。
        do {
            _ = try await client.readTextFile(sessionID: sessionID, path: "/tmp/project/../secret.txt")
            XCTFail("路径穿越应被拒绝")
        } catch let error as ACPFileClientError {
            guard case .pathOutsideWorkspace = error else {
                return XCTFail("期望 pathOutsideWorkspace，得到 \(error)")
            }
        }
    }

    func testClientErrorPropagates() async throws {
        let sessions = ACPSessionManager(conversationFactory: MockConversationFactory())
        let sessionID = try sessions.createSession(cwd: "/tmp/project")
        let auto = AutoClient()
        auto.errorToThrow = ACPError(code: ACPErrorCode.internalError, message: "boom")
        let client = ACPFileClient(
            requester: auto.makeRequester(),
            capabilities: capabilities(read: true, write: true),
            sessions: sessions
        )
        do {
            _ = try await client.readTextFile(sessionID: sessionID, path: "/tmp/project/a.txt")
            XCTFail("应传播远端错误")
        } catch let error as ACPClientRequester.RequestError {
            guard case .remote(let acpError) = error else {
                return XCTFail("期望 remote，得到 \(error)")
            }
            XCTAssertEqual(acpError.message, "boom")
        }
    }

    // MARK: - 纯函数

    func testIsContainedUsesPathComponents() {
        let root = URL(fileURLWithPath: "/tmp/project")
        XCTAssertTrue(ACPFileClient.isContained(URL(fileURLWithPath: "/tmp/project/a.txt"), in: root))
        XCTAssertTrue(ACPFileClient.isContained(root, in: root))
        // 前缀相同但并非其子目录：不得误判。
        XCTAssertFalse(ACPFileClient.isContained(URL(fileURLWithPath: "/tmp/project-other/a"), in: root))
        XCTAssertFalse(ACPFileClient.isContained(URL(fileURLWithPath: "/etc/passwd"), in: root))
    }
}
