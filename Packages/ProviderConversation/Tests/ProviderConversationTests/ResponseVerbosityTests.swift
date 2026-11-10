import Foundation
import Testing
@testable import ProviderConversation

/// `ResponseVerbosity` 持久化枚举契约测试。
///
/// V4（ZCode）是消息列表的**呈现变体**，不是回复长度策略：
/// 因此这里只锁定 rawValue / 往返 / 展示名 / 枚举集合，
/// 不允许它影响提示词或默认回复级别。
@Suite("ResponseVerbosity 持久化枚举")
struct ResponseVerbosityTests {

    @Test("V4 的 rawValue 是 v4")
    func zcodeRawValueIsV4() {
        #expect(ResponseVerbosity.zcode.rawValue == "v4")
    }

    @Test("init(rawValue:) 接受 v4 与 zcode 两个别名")
    func zcodeAcceptsBothAliases() {
        #expect(ResponseVerbosity(rawValue: "v4") == .zcode)
        #expect(ResponseVerbosity(rawValue: "zcode") == .zcode)
        #expect(ResponseVerbosity(rawValue: "ZCODE") == .zcode)
    }

    @Test("默认级别仍是 V2 标准")
    func defaultVerbosityRemainsStandard() {
        #expect(ResponseVerbosity.defaultVerbosity == .standard)
    }

    @Test("allCases 按 v1 v2 v3 v4 顺序包含四种级别")
    func allCasesContainFourLevelsInOrder() {
        #expect(ResponseVerbosity.allCases.map(\.rawValue) == ["v1", "v2", "v3", "v4"])
    }

    @Test("V1–V3 的 rawValue 保持不变")
    func existingLevelsRemainStable() {
        #expect(ResponseVerbosity.brief.rawValue == "v1")
        #expect(ResponseVerbosity.standard.rawValue == "v2")
        #expect(ResponseVerbosity.detailed.rawValue == "v3")
    }

    // Note: 展示名与描述已由 #920 从 `ProviderConversation` 迁到
    //   `PluginConversationVerbosity.VerbosityLocalization`（多语言）。
    //   这里不再断言文案本身，只锁定「Provider 不再产出任何语言的显示名」
    //   这一契约，避免 UI 文案回归到内核包里。

    @Test("JSON 编解码往返所有级别不丢失")
    func jsonRoundTripPreservesEveryLevel() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for level in ResponseVerbosity.allCases {
            let data = try encoder.encode(level)
            let decoded = try decoder.decode(ResponseVerbosity.self, from: data)
            #expect(decoded == level)
            #expect(decoded.rawValue == level.rawValue)
        }
    }

    @Test("以字符串形式持久化 v4 后能解回 ZCode")
    func stringPersistedV4DecodesBackToZCode() throws {
        let persisted = ResponseVerbosity.zcode.rawValue
        #expect(persisted == "v4")
        #expect(ResponseVerbosity(rawValue: persisted) == .zcode)
    }

    @Test("未知 rawValue 不被误判为 V4")
    func unknownRawValueIsRejected() {
        #expect(ResponseVerbosity(rawValue: "v5") == nil)
        #expect(ResponseVerbosity(rawValue: "") == nil)
    }
}
