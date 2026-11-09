import Foundation
import MailCore
import XCTest
@testable import KitMail

/// 回归 #1073：MailCore 的 Void 操作成功时回调为 `completion(nil, nil)`，
/// 桥接不能因此报 "empty result"。
final class MailCoreCallbackBridgeTests: XCTestCase {
    private let bridge = MailCoreCallbackBridge(queue: DispatchQueue(label: "KitMailTests.bridge"))

    func testVoidOperationSucceedsWithoutValue() async throws {
        try await bridge.performVoid { completion in
            completion(nil)
        }
    }

    func testVoidOperationSurfacesMappedError() async {
        do {
            try await bridge.performVoid { completion in
                completion(NSError(domain: MCOErrorDomain, code: MCOErrorCode.authentication.rawValue))
            }
            XCTFail("expected authFailed")
        } catch let error as MailError {
            XCTAssertEqual(error, .authFailed)
        } catch {
            XCTFail("unexpected error \(error)")
        }
    }

    func testVoidOperationTimesOutWhenCallbackNeverFires() async {
        do {
            try await bridge.performVoid(timeout: 0.05) { _ in }
            XCTFail("expected network timeout")
        } catch let error as MailError {
            XCTAssertEqual(error, .network)
        } catch {
            XCTFail("unexpected error \(error)")
        }
    }

    func testValueOperationStillRejectsMissingValue() async {
        do {
            let _: Data = try await bridge.perform { completion in
                completion(nil, nil)
            }
            XCTFail("expected protocolError")
        } catch let error as MailError {
            guard case .protocolError(let message) = error else {
                return XCTFail("expected protocolError, got \(error)")
            }
            XCTAssertEqual(message, "empty result")
        } catch {
            XCTFail("unexpected error \(error)")
        }
    }
}
