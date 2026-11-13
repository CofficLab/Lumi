import Foundation
import Testing
@testable import BrowserPlugin

/// 回归 #831：本地地址分类器曾用字符串前缀 `fc`/`fd` 判定 IPv6 ULA，
/// 未先确认输入是 IPv6 字面量，导致 `fdic.gov` 等公网域名被误判为内网，
/// 触发错误的「本地网络」审批并阻断链接导航。只有含 `:` 的 IPv6 字面量
/// 才可能属于 `fc00::/7`。
@Suite("BrowserLocalHostClassification")
struct BrowserLocalHostClassificationTests {

    @Test("fc/fd 开头的公网域名不得被判为内网（回归 #831）")
    func publicDomainsStartingWithFcOrFdAreNotLocal() {
        for host in ["fdic.gov", "fc.com", "fcbayern.com", "fdj.fr", "fc.example.com"] {
            #expect(BrowserSessionManager.isLocalHost(host) == false, "\(host) 是公网域名")
        }
        #expect(BrowserSessionManager.requiresLocalAccessApproval("https://fdic.gov") == false)
        #expect(BrowserSessionManager.requiresLocalAccessApproval("https://fc.example.com/path") == false)
    }

    @Test("真正的 IPv6 ULA 与链路本地地址仍判为内网")
    func ipv6ULAAndLinkLocalAreLocal() {
        for host in ["fc00::1", "fd12:3456::1", "fe80::1", "[fc00::1]", "[fd00::abcd]"] {
            #expect(BrowserSessionManager.isLocalHost(host) == true, "\(host) 是 IPv6 内网地址")
        }
        #expect(BrowserSessionManager.requiresLocalAccessApproval("http://[fc00::1]/") == true)
        #expect(BrowserSessionManager.requiresLocalAccessApproval("http://[fe80::1]:8080/") == true)
    }

    @Test("既有本地与公网分类保持不变")
    func existingLocalAndPublicClassificationsArePreserved() {
        for host in ["localhost", "::1", "printer.local", "server.internal",
                     "10.0.0.1", "192.168.1.1", "127.0.0.1", "169.254.1.1", "172.16.0.1"] {
            #expect(BrowserSessionManager.isLocalHost(host) == true, "\(host) 应为内网")
        }
        for host in ["example.com", "8.8.8.8", "1.1.1.1", "github.com"] {
            #expect(BrowserSessionManager.isLocalHost(host) == false, "\(host) 应为公网")
        }
    }
}
