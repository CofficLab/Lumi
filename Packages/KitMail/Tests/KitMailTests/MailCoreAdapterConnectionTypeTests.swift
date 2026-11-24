import XCTest
import MailCore
@testable import KitMail

/// 回归 #309：iCloud/Outlook 预设的 SMTP 端口是 587（STARTTLS 提交端口），
/// 但旧实现把共享的 `useTLS=true` 直接映射为隐式 TLS 直连，587 端口上
/// 握手期即失败。587 必须走 STARTTLS；隐式 TLS 仅用于 465 端口。
final class MailCoreAdapterConnectionTypeTests: XCTestCase {

    private func makeAdapter(
        smtpPort: UInt16,
        imapPort: UInt16 = 993,
        useTLS: Bool
    ) -> MailCoreAdapter {
        MailCoreAdapter(
            account: MailAccountConfig(
                displayName: "Test",
                email: "test@example.com",
                imapHost: "imap.example.com",
                imapPort: imapPort,
                smtpHost: "smtp.example.com",
                smtpPort: smtpPort,
                username: "test@example.com",
                useTLS: useTLS
            ),
            password: "unused"
        )
    }

    func testSMTPOnPort587UsesSTARTTLSEvenWithUseTLS() {
        let adapter = makeAdapter(smtpPort: 587, useTLS: true)
        XCTAssertEqual(adapter.smtpConnectionType, .startTLS)
        // 共享开关的隐式 TLS 语义不受影响：IMAP 993 仍是直连 TLS。
        XCTAssertEqual(adapter.imapConnectionType, .TLS)
    }

    func testSMTPOnPort465KeepsImplicitTLS() {
        let adapter = makeAdapter(smtpPort: 465, useTLS: true)
        XCTAssertEqual(adapter.smtpConnectionType, .TLS)
    }

    func testSMTPFollowsUseTLSFlagOnOtherPorts() {
        XCTAssertEqual(makeAdapter(smtpPort: 2465, useTLS: false).smtpConnectionType, .startTLS)
        XCTAssertEqual(makeAdapter(smtpPort: 2465, useTLS: true).smtpConnectionType, .TLS)
    }
}
