import Foundation
import Testing
@testable import ProviderStore

/// `StoreTier` 的排序与档位判定。
@Suite("StoreTier")
struct StoreTierTests {

    /// 档位是有序的：比较运算符直接表达「至少 Pro」这类规则。
    @Test func tiersAreOrderedByRawValue() {
        #expect(StoreTier.none < StoreTier.pro)
        #expect(StoreTier.pro < StoreTier.ultimate)
        #expect(StoreTier.none < StoreTier.ultimate)
        #expect(!(StoreTier.ultimate < StoreTier.pro))
    }

    /// 免费档判定。
    @Test func freeTierDetection() {
        #expect(StoreTier.none.isFree)
        #expect(!StoreTier.pro.isFree)
        #expect(!StoreTier.ultimate.isFree)
    }

    /// 「至少 Pro」判定：专业档与旗舰档都满足。
    @Test func proOrHigherDetection() {
        #expect(!StoreTier.none.isProOrHigher)
        #expect(StoreTier.pro.isProOrHigher)
        #expect(StoreTier.ultimate.isProOrHigher)
    }

    /// 「旗舰及以上」判定。
    @Test func ultimateOrHigherDetection() {
        #expect(!StoreTier.none.isUltimateOrHigher)
        #expect(!StoreTier.pro.isUltimateOrHigher)
        #expect(StoreTier.ultimate.isUltimateOrHigher)
    }

    /// 档位可按原始值编解码，用于缓存与跨进程传递。
    @Test func tierRoundTripsThroughCodable() throws {
        for tier in StoreTier.allCases {
            let data = try JSONEncoder().encode(tier)
            let decoded = try JSONDecoder().decode(StoreTier.self, from: data)
            #expect(decoded == tier)
        }
    }

    /// 档位原始值固定，避免跨版本缓存语义漂移。
    @Test func tierRawValuesAreStable() {
        #expect(StoreTier.none.rawValue == 0)
        #expect(StoreTier.pro.rawValue == 1)
        #expect(StoreTier.ultimate.rawValue == 2)
    }
}
