import XCTest
import WebKit
@testable import PluginMail

/// 回归 #729：远程内容默认拦截（CSP），用户点击的链接不被远程开关阻断。
final class MailHTMLContentPolicyTests: XCTestCase {
    func testUnauthorizedHTMLBlocksRemoteSubresources() {
        let html = MailHTMLContentView.baseHTML(with: "<p>hi</p>", allowsRemoteContent: false)
        XCTAssertTrue(html.contains("Content-Security-Policy"), "默认应注入 CSP")
        XCTAssertTrue(html.contains("default-src 'none'"), "默认应拒绝所有远程子资源请求")
        XCTAssertTrue(html.contains("style-src 'unsafe-inline'"), "保留内联排版样式")
    }

    func testAuthorizedHTMLOmitsRestrictivePolicy() {
        let html = MailHTMLContentView.baseHTML(with: "<p>hi</p>", allowsRemoteContent: true)
        XCTAssertFalse(html.contains("Content-Security-Policy"), "授权后不再注入限制性策略")
        XCTAssertTrue(html.contains("<p>hi</p>"))
    }

    func testLinkActivatedOpensExternallyEvenWithoutAuthorization() {
        let url = URL(string: "https://example.com/document")!
        let decision = MailHTMLContentView.navigationDecision(
            for: url,
            navigationType: .linkActivated,
            allowsRemoteContent: false
        )
        XCTAssertEqual(decision, .openExternally(url), "用户点击的链接不应被远程图片开关取消")
    }

    func testNonUserRemoteNavigationRequiresAuthorization() {
        let url = URL(string: "https://example.com/frame")!
        XCTAssertEqual(
            MailHTMLContentView.navigationDecision(
                for: url,
                navigationType: .other,
                allowsRemoteContent: false
            ),
            .cancel
        )
        XCTAssertEqual(
            MailHTMLContentView.navigationDecision(
                for: url,
                navigationType: .other,
                allowsRemoteContent: true
            ),
            .allow
        )
    }

    func testLocalNavigationAlwaysAllowed() {
        XCTAssertEqual(
            MailHTMLContentView.navigationDecision(
                for: nil,
                navigationType: .other,
                allowsRemoteContent: false
            ),
            .allow
        )
        XCTAssertEqual(
            MailHTMLContentView.navigationDecision(
                for: URL(string: "about:blank"),
                navigationType: .other,
                allowsRemoteContent: false
            ),
            .allow
        )
    }
}
