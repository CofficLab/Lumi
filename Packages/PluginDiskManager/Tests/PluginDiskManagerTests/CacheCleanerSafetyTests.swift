import Foundation
import Testing
@testable import PluginDiskManager

/// 回归 #659：Xcode Archives 里是已发布构建与 dSYM，缓存重建不出来，
/// 不能归入可安全清理的缓存，更不能在扫描后默认勾选。
@Suite("CacheCleanerSafety")
struct CacheCleanerSafetyTests {

    @Test("Xcode Archives 归入需要用户确认的级别，不再被自动勾选")
    func xcodeArchivesRequiresExplicitSelection() throws {
        let rules = CacheCleanerService.shared.scanRules
        let archivesRule = try #require(rules.first { rule in
            rule.paths.contains { $0.hasSuffix("/Library/Developer/Xcode/Archives") }
        })

        #expect(archivesRule.level == .medium)
        #expect(
            !rules.contains { rule in
                rule.level == .safe && rule.paths.contains { $0.contains("Xcode/Archives") }
            },
            "任何安全级别规则都不得包含 Archives"
        )
    }

    @Test("开发者工具缓存不再包含 Archives")
    func developerToolCacheNoLongerContainsArchives() throws {
        let rule = try #require(CacheCleanerService.shared.scanRules.first { $0.id == "dev_cache" })

        #expect(!rule.paths.contains { $0.contains("Xcode/Archives") })
    }
}
