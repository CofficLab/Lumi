import Foundation
import Testing
@testable import LumiAppKit

/// `FeedURLDetector.detectFeedURL(primary:fallback:reachabilityChecker:)` 的纯逻辑测试
struct FeedURLDetectorStaticTests {

    @Test
    func primaryReachableReturnsPrimary() async {
        let primary = URL(string: "https://primary.example/appcast.xml")!
        let fallback = URL(string: "https://fallback.example/appcast.xml")!
        let checker = StubURLPairReachability(
            primary: true,
            fallback: false
        )

        let resolved = await FeedURLDetector.detectFeedURL(
            primary: primary,
            fallback: fallback,
            reachabilityChecker: checker
        )
        #expect(resolved == primary)
    }

    @Test
    func primaryUnreachableReturnsFallback() async {
        let primary = URL(string: "https://primary.example/appcast.xml")!
        let fallback = URL(string: "https://fallback.example/appcast.xml")!
        let checker = StubURLPairReachability(
            primary: false,
            fallback: true
        )

        let resolved = await FeedURLDetector.detectFeedURL(
            primary: primary,
            fallback: fallback,
            reachabilityChecker: checker
        )
        #expect(resolved == fallback)
    }

    @Test
    func bothUnreachableStillReturnsFallback() async {
        // 设计意图：探测失败时仍返回 fallback，让 Sparkle 自行决定。
        // 验证这一行为避免 SDK 被卡死。
        let primary = URL(string: "https://primary.example/appcast.xml")!
        let fallback = URL(string: "https://fallback.example/appcast.xml")!
        let checker = StubURLPairReachability(
            primary: false,
            fallback: false
        )

        let resolved = await FeedURLDetector.detectFeedURL(
            primary: primary,
            fallback: fallback,
            reachabilityChecker: checker
        )
        #expect(resolved == fallback)
    }
}

// MARK: - 测试辅助类型

/// 简易可达性 stub：根据 URL 路径判断可达性。
private struct StubURLPairReachability: FeedURLReachabilityChecker {
    let primary: Bool
    let fallback: Bool

    func isReachable(_ url: URL) async -> Bool {
        try? await Task.sleep(for: .milliseconds(1))
        return url.absoluteString.contains("primary") ? primary : fallback
    }
}