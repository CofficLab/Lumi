import Foundation
import KitAgentTool
import Testing
@testable import BrowserPlugin

/// 回归 #830：`localhost.`（带 DNS 根点的合法 FQDN）在 macOS 上同样解析到
/// 127.0.0.1 / ::1，但分类器只做字符串比对，把它当成公网地址：
/// `browser_open` 的风险等级降为 `.low`，本地访问审批被整条绕过。
///
/// 分类与审批键都必须先归一化主机名，`localhost.` 与 `localhost` 才是
/// 同一个本地主机。
@MainActor
@Suite("Browser 本地地址的 DNS 根点归一化")
struct BrowserTrailingDotHostTests {

    // MARK: - 分类

    @Test("带 DNS 根点的本地主机仍判为内网（回归 #830）")
    func trailingRootDotLocalHostsAreStillLocal() {
        for host in ["localhost.", "LOCALHOST.", "printer.local.", "server.internal.",
                     "box.lan.", "dev.localhost.", "127.0.0.1.", "10.0.0.1.",
                     "192.168.1.1.", "169.254.1.1.", "172.16.0.1."] {
            #expect(BrowserSessionManager.isLocalHost(host) == true, "\(host) 应为内网")
        }
        #expect(BrowserSessionManager.requiresLocalAccessApproval("http://localhost.:3000") == true)
        #expect(BrowserSessionManager.requiresLocalAccessApproval("http://printer.local.:8080/x") == true)
        #expect(BrowserSessionManager.requiresLocalAccessApproval("http://127.0.0.1.:9000/") == true)
    }

    @Test("带根点的公网域名不得被误判为内网")
    func trailingRootDotKeepsPublicHostsPublic() {
        for host in ["example.com.", "github.com.", "8.8.8.8.", "1.1.1.1.", "fdic.gov."] {
            #expect(BrowserSessionManager.isLocalHost(host) == false, "\(host) 应为公网")
        }
        #expect(BrowserSessionManager.requiresLocalAccessApproval("https://example.com.") == false)
    }

    @Test("多个根点同样归一化，方向偏保守")
    func repeatedRootDotsAreNormalized() {
        // 非法但可能出现的写法：宁可多要一次审批，也不能放行回环地址。
        for host in ["localhost..", "localhost..."] {
            #expect(BrowserSessionManager.isLocalHost(host) == true, "\(host) 应为内网")
        }
        #expect(BrowserSessionManager.normalizedHost("localhost..") == "localhost")
    }

    @Test("既有归一化行为保持不变")
    func existingNormalizationIsPreserved() {
        #expect(BrowserSessionManager.normalizedHost("[::1]") == "::1")
        #expect(BrowserSessionManager.normalizedHost("LOCALHOST") == "localhost")
        #expect(BrowserSessionManager.normalizedHost("localhost") == "localhost")
        #expect(BrowserSessionManager.normalizedHost("") == "")
        for host in ["localhost", "::1", "[fc00::1]", "printer.local", "127.0.0.1"] {
            #expect(BrowserSessionManager.isLocalHost(host) == true, "\(host) 应为内网")
        }
        for host in ["example.com", "8.8.8.8", "fdic.gov"] {
            #expect(BrowserSessionManager.isLocalHost(host) == false, "\(host) 应为公网")
        }
    }

    // MARK: - 工具风险等级

    @Test("带根点的回环地址在打开与导航工具上都是高风险")
    func openAndNavigateToolsRequireApprovalForTrailingDot() {
        let manager = BrowserSessionManager()
        let openTool = BrowserOpenTool(sessions: manager)
        let navigateTool = BrowserNavigateTool(sessions: manager)

        for url in ["http://localhost.:3000", "http://127.0.0.1.:3000", "http://printer.local.:8080"] {
            #expect(openTool.permissionRiskLevel(arguments: ["url": ToolArgument(url)]) == .high, "\(url)")
            #expect(navigateTool.permissionRiskLevel(arguments: [
                "action": ToolArgument("goto"),
                "url": ToolArgument(url),
            ]) == .high, "\(url)")
        }
        #expect(openTool.permissionRiskLevel(arguments: ["url": ToolArgument("https://example.com.")]) == .low)
    }

    // MARK: - 打开前的守卫

    @Test("未获批准时带根点的回环地址被拦下，且不创建会话")
    func openWithoutApprovalIsBlocked() async {
        let manager = BrowserSessionManager()
        let conversationID = UUID()

        do {
            _ = try await manager.open(
                "http://localhost.:3000",
                conversationID: conversationID,
                localAccessApproved: false
            )
            Issue.record("未批准时不得打开 http://localhost.:3000")
        } catch let error as BrowserSession.SessionError {
            guard case .blockedLocalNavigation = error else {
                Issue.record("期望 blockedLocalNavigation，实际 \(error)")
                return
            }
        } catch {
            Issue.record("期望 SessionError，实际 \(error)")
            return
        }

        // 守卫必须在建 WKWebView 之前生效。
        #expect(!manager.hasSession(for: conversationID))
    }

    // MARK: - 审批键

    @Test("审批键按归一化主机记录")
    func approvedHostKeyIsNormalized() throws {
        let loopback = try #require(URL(string: "http://localhost.:3000"))
        #expect(BrowserSessionManager.approvedHostKey(for: loopback, localAccessApproved: true) == "localhost")

        let ipv6 = try #require(URL(string: "http://[::1]:8080/"))
        #expect(BrowserSessionManager.approvedHostKey(for: ipv6, localAccessApproved: true) == "::1")

        let bonjour = try #require(URL(string: "http://PRINTER.LOCAL./"))
        #expect(BrowserSessionManager.approvedHostKey(for: bonjour, localAccessApproved: true) == "printer.local")

        // 未批准时不留任何键，否则等于默认放行。
        #expect(BrowserSessionManager.approvedHostKey(for: loopback, localAccessApproved: false) == nil)
    }

    @Test("批准 localhost 后等价写法都算已批准，无关主机不算")
    func approvedLocalHostCoversEquivalentForms() throws {
        let manager = BrowserSessionManager()
        let session = manager.session(for: UUID())

        let loopback = try #require(URL(string: "http://localhost.:3000"))
        let key = try #require(BrowserSessionManager.approvedHostKey(
            for: loopback,
            localAccessApproved: true
        ))
        session.approvedLocalHost = key

        for host in ["localhost", "localhost.", "LOCALHOST.", "localhost.."] {
            #expect(session.hasApprovedLocalHost(host) == true, "\(host) 与 localhost 等价")
        }
        for host in ["evil.com", "localhost.evil.com", "example.com."] {
            #expect(session.hasApprovedLocalHost(host) == false, "\(host) 不是已批准主机")
        }

        // 没有审批记录时任何写法都不算已批准。
        session.approvedLocalHost = nil
        #expect(session.hasApprovedLocalHost("localhost.") == false)
        #expect(session.hasApprovedLocalHost("localhost") == false)
    }
}