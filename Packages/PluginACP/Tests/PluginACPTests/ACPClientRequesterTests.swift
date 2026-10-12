import Foundation
import XCTest
@testable import PluginACP
import ProviderACP

@MainActor
final class ACPClientRequesterTests: XCTestCase {
    private final class Box {
        var messages: [ACPMessage] = []
    }

    private func makeRequester(
        box: Box,
        timeout: TimeInterval = 60,
        permissionTimeout: TimeInterval? = nil
    ) -> ACPClientRequester {
        ACPClientRequester(
            onSend: { [box] message in box.messages.append(message) },
            timeout: timeout,
            permissionTimeout: permissionTimeout
        )
    }

    /// 等待出站请求出现。
    ///
    /// 测试本身是 `async` 且 MainActor 隔离的，因此必须用 `await` 让出执行权，
    /// 而不能 busy-wait `RunLoop`（后者会占住 MainActor，令 requester 任务无法运行）。
    private func waitForRequest(_ box: Box, timeout: TimeInterval = 5) async -> JSONValue? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let id = lastRequestID(box) { return id }
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(5))
        }
        return lastRequestID(box)
    }

    /// 等待条件成立。
    private func waitUntil(_ condition: () -> Bool, timeout: TimeInterval = 5) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() && Date() < deadline {
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(5))
        }
    }

    /// 提取最近一条出站请求的 id。
    private func lastRequestID(_ box: Box) -> JSONValue? {
        box.messages.reversed().compactMap { message -> JSONValue? in
            if case .request(let id, _, _) = message { return id }
            return nil
        }.first
    }

    func testRequestResolvesWithClientResult() async throws {
        let box = Box()
        let requester = makeRequester(box: box)

        let task = Task { @MainActor in
            try await requester.request(
                method: ACPMethod.fsReadTextFile,
                params: .object([:]),
                sessionID: ACPSessionId(rawValue: "sess_a")
            )
        }
        let requestID = await waitForRequest(box)
        let id = try XCTUnwrap(requestID)
        requester.handleResponse(id: id, result: .object(["content": .string("hi")]))

        let result = try await task.value
        XCTAssertEqual(result, .object(["content": .string("hi")]))
        XCTAssertEqual(requester.pendingCount, 0)
    }

    func testTimeoutThrowsAndClearsWaiter() async throws {
        let box = Box()
        let requester = makeRequester(box: box, timeout: 0.2)

        let task = Task { @MainActor in
            try await requester.request(
                method: ACPMethod.fsReadTextFile,
                params: .null,
                sessionID: ACPSessionId(rawValue: "sess_a")
            )
        }
        do {
            _ = try await task.value
            XCTFail("期望超时错误")
        } catch let error as ACPClientRequester.RequestError {
            guard case .timeout = error else {
                return XCTFail("期望 timeout，得到 \(error)")
            }
        }
        XCTAssertEqual(requester.pendingCount, 0)
    }

    func testRemoteErrorMessagePropagates() async throws {
        let box = Box()
        let requester = makeRequester(box: box)

        let task = Task { @MainActor in
            try await requester.request(
                method: ACPMethod.fsWriteTextFile,
                params: .null,
                sessionID: ACPSessionId(rawValue: "sess_a")
            )
        }
        let requestID = await waitForRequest(box)
        let id = try XCTUnwrap(requestID)
        requester.handleError(
            id: id,
            error: ACPError(code: ACPErrorCode.requestCancelled, message: "cancelled")
        )
        do {
            _ = try await task.value
            XCTFail("期望远端错误")
        } catch let error as ACPClientRequester.RequestError {
            guard case .remote(let acpError) = error else {
                return XCTFail("期望 remote，得到 \(error)")
            }
            XCTAssertEqual(acpError.code, ACPErrorCode.requestCancelled)
        }
    }

    func testCancelRequestsForSessionOnlyAffectsThatSession() async throws {
        let box = Box()
        let requester = makeRequester(box: box)
        let target = ACPSessionId(rawValue: "sess_target")
        let other = ACPSessionId(rawValue: "sess_other")

        let targetTask = Task { @MainActor in
            try await requester.request(method: "m", params: .null, sessionID: target)
        }
        await waitUntil { requester.pendingCount == 1 }
        let otherTask = Task { @MainActor in
            try await requester.request(method: "m", params: .null, sessionID: other)
        }
        await waitUntil { requester.pendingCount == 2 }

        requester.cancelRequests(for: target)
        XCTAssertEqual(requester.pendingCount, 1)

        do {
            _ = try await targetTask.value
            XCTFail("目标会话请求应被取消")
        } catch let error as ACPClientRequester.RequestError {
            guard case .cancelled = error else {
                return XCTFail("期望 cancelled，得到 \(error)")
            }
        }
        // 另一会话的请求保持挂起。
        XCTAssertEqual(requester.pendingCount, 1)
        requester.cancelAll()
        _ = try? await otherTask.value
        XCTAssertEqual(requester.pendingCount, 0)
    }

    func testResponseAfterCancelIsIgnored() async throws {
        let box = Box()
        let requester = makeRequester(box: box)
        let sessionID = ACPSessionId(rawValue: "sess_x")

        let task = Task { @MainActor in
            try await requester.request(method: "m", params: .null, sessionID: sessionID)
        }
        let requestID = await waitForRequest(box)
        let id = try XCTUnwrap(requestID)

        requester.cancelRequests(for: sessionID)
        // 迟到响应不应崩溃，也不应改变结果（continuation 已 resume）。
        requester.handleResponse(id: id, result: .string("late"))
        do {
            _ = try await task.value
            XCTFail("应已取消")
        } catch let error as ACPClientRequester.RequestError {
            guard case .cancelled = error else {
                return XCTFail("期望 cancelled，得到 \(error)")
            }
        }
    }

    func testAgentIDsStartAboveClientRange() async throws {
        let box = Box()
        let requester = makeRequester(box: box)
        let task = Task { @MainActor in
            try await requester.request(
                method: "m",
                params: .null,
                sessionID: ACPSessionId(rawValue: "sess_a")
            )
        }
        let requestID = await waitForRequest(box)
        let id = try XCTUnwrap(requestID)
        // Agent 侧 ID 从 1000 起，避免与 Client 的 1..n 混淆。
        guard case .number(let value) = id else {
            return XCTFail("期望数字 id")
        }
        XCTAssertGreaterThanOrEqual(value, 1000)
        requester.cancelAll()
        _ = try? await task.value
    }
}
