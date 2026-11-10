import Foundation
@testable import LibGit2Swift
import XCTest

/// 网络错误检测逻辑的单元测试
/// 测试 isNetworkError 方法能否正确识别 SSL/网络相关错误
final class NetworkErrorTests: XCTestCase {

    // MARK: - SSL/TLS 错误

    func testSecureTransportError9806() {
        XCTAssertTrue(LibGit2.isNetworkError(-1, errorMessage: "SecureTransport error: -9806"))
    }

    func testSecureTransportError9814() {
        XCTAssertTrue(LibGit2.isNetworkError(-1, errorMessage: "SecureTransport error: -9814"))
    }

    func testSecureTransportError9802() {
        XCTAssertTrue(LibGit2.isNetworkError(-1, errorMessage: "SecureTransport error: -9802"))
    }

    func testSecureTransportError9843() {
        XCTAssertTrue(LibGit2.isNetworkError(-1, errorMessage: "SecureTransport error: -9843"))
    }

    func testSSLErrorGeneric() {
        XCTAssertTrue(LibGit2.isNetworkError(-1, errorMessage: "SSL certificate problem: unable to get local issuer certificate"))
    }

    func testTLSError() {
        XCTAssertTrue(LibGit2.isNetworkError(-1, errorMessage: "TLS handshake timeout"))
    }

    func testCertificateError() {
        XCTAssertTrue(LibGit2.isNetworkError(-1, errorMessage: "certificate verify failed"))
    }

    // MARK: - 网络连接错误

    func testCouldNotResolveHost() {
        XCTAssertTrue(LibGit2.isNetworkError(-1, errorMessage: "Could not resolve host: github.com"))
    }

    func testFailedToConnect() {
        XCTAssertTrue(LibGit2.isNetworkError(-1, errorMessage: "Failed to connect to github.com port 443"))
    }

    func testConnectionTimedOut() {
        XCTAssertTrue(LibGit2.isNetworkError(-1, errorMessage: "Connection timed out"))
    }

    func testConnectionRefused() {
        XCTAssertTrue(LibGit2.isNetworkError(-1, errorMessage: "Connection refused"))
    }

    func testNetworkUnreachable() {
        XCTAssertTrue(LibGit2.isNetworkError(-1, errorMessage: "Network is unreachable"))
    }

    func testNoRouteToHost() {
        XCTAssertTrue(LibGit2.isNetworkError(-1, errorMessage: "No route to host"))
    }

    func testOperationTimedOut() {
        XCTAssertTrue(LibGit2.isNetworkError(-1, errorMessage: "Operation timed out"))
    }

    func testConnectionReset() {
        XCTAssertTrue(LibGit2.isNetworkError(-1, errorMessage: "Connection reset by peer"))
    }

    func testBrokenPipe() {
        XCTAssertTrue(LibGit2.isNetworkError(-1, errorMessage: "Broken pipe"))
    }

    // MARK: - 代理错误

    func testProxyError() {
        XCTAssertTrue(LibGit2.isNetworkError(-1, errorMessage: "Failed to connect to proxy"))
    }

    func testTunnelError() {
        XCTAssertTrue(LibGit2.isNetworkError(-1, errorMessage: "tunnel connection failed"))
    }

    // MARK: - 传输层错误

    func testCurlError() {
        XCTAssertTrue(LibGit2.isNetworkError(-1, errorMessage: "curl error: SSL connection timeout"))
    }

    func testSocketError() {
        XCTAssertTrue(LibGit2.isNetworkError(-1, errorMessage: "socket hang up"))
    }

    // MARK: - 大小写不敏感

    func testCaseInsensitive() {
        XCTAssertTrue(LibGit2.isNetworkError(-1, errorMessage: "SSL CERTIFICATE PROBLEM"))
        XCTAssertTrue(LibGit2.isNetworkError(-1, errorMessage: "Could NOT Resolve Host"))
        XCTAssertTrue(LibGit2.isNetworkError(-1, errorMessage: "SECURETRANSPORT error"))
    }

    // MARK: - 非网络错误（应返回 false）

    func testAuthenticationErrorNotDetectedAsNetwork() {
        XCTAssertFalse(LibGit2.isNetworkError(-1, errorMessage: "Authentication failed"))
    }

    func testGenericPushErrorNotDetectedAsNetwork() {
        XCTAssertFalse(LibGit2.isNetworkError(-1, errorMessage: "Push failed - non-fast-forward"))
    }

    func testMergeConflictNotDetectedAsNetwork() {
        XCTAssertFalse(LibGit2.isNetworkError(-1, errorMessage: "Merge conflict detected"))
    }

    func testEmptyMessageNotDetectedAsNetwork() {
        XCTAssertFalse(LibGit2.isNetworkError(-1, errorMessage: ""))
    }

    func testGenericErrorMessageNotDetectedAsNetwork() {
        XCTAssertFalse(LibGit2.isNetworkError(-1, errorMessage: "Unknown push error"))
    }

    // MARK: - LibGit2Error.networkError 类型验证

    func testNetworkErrorCaseAssociatedValue() {
        let error = LibGit2Error.networkError(-9806)
        if case let .networkError(code) = error {
            XCTAssertEqual(code, -9806)
        } else {
            XCTFail("Expected networkError case")
        }
    }

    func testNetworkErrorDescription() {
        let error = LibGit2Error.networkError(-9806)
        XCTAssertTrue(error.errorDescription?.contains("-9806") ?? false)
    }
}
