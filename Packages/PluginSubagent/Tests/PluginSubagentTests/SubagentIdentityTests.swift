import Foundation
import ProviderMessage
import Testing
@testable import PluginSubagent

/// #1328 Task 1：子代理的稳定身份。
///
/// 名字是树内寻址的唯一键：3-32 个小写字母/数字/连字符，首字符必须是字母。
/// 缺省名按 `agent-N` 取第一个空位；同名永远拒绝，不做静默改写。
@MainActor
@Suite("Subagent Identity")
struct SubagentIdentityTests {

    // MARK: - 校验

    @Test("合法名字：3-32 位、小写字母开头、允许数字与连字符")
    func acceptsValidNames() {
        let valid = [
            "abc",
            "agent-1",
            "explorer",
            "a-b-c",
            "a12",
            String(repeating: "a", count: 32),
        ]
        for name in valid {
            #expect(SubagentIdentity.isValidName(name), "expected valid: \(name)")
        }
    }

    @Test("非法名字：长度、大小写、首字符与字符集")
    func rejectsInvalidNames() {
        let invalid = [
            "",
            "ab",
            String(repeating: "a", count: 33),
            "Agent-1",
            "1agent",
            "-agent",
            "agent_1",
            "agent 1",
            "代理",
        ]
        for name in invalid {
            #expect(!SubagentIdentity.isValidName(name), "expected invalid: \(name)")
        }
    }

    // MARK: - 默认命名

    @Test("没有子代理时默认 agent-1")
    func defaultNameStartsAtOne() {
        #expect(SubagentIdentity.defaultName(existing: []) == "agent-1")
    }

    @Test("默认名取第一个空位，不因中间空号而继续增长")
    func defaultNameUsesFirstFreeSlot() {
        #expect(SubagentIdentity.defaultName(existing: ["agent-1"]) == "agent-2")
        #expect(SubagentIdentity.defaultName(existing: ["agent-2"]) == "agent-1")
        #expect(SubagentIdentity.defaultName(existing: ["agent-1", "agent-3"]) == "agent-2")
        #expect(SubagentIdentity.defaultName(existing: ["explorer"]) == "agent-1")
    }

    // MARK: - 解析

    @Test("未提供名字时使用默认名")
    func resolveWithoutRequestedUsesDefault() throws {
        let name = try SubagentIdentity.resolve(requested: nil, existing: ["agent-1"])
        #expect(name == "agent-2")
    }

    @Test("提供合法且唯一的名字时原样返回")
    func resolveKeepsUniqueRequestedName() throws {
        let name = try SubagentIdentity.resolve(requested: "explorer", existing: ["agent-1"])
        #expect(name == "explorer")
    }

    @Test("提供非法名字时抛出 invalidName")
    func resolveThrowsForInvalidName() {
        #expect(throws: SubagentIdentityError.invalidName("Explorer")) {
            _ = try SubagentIdentity.resolve(requested: "Explorer", existing: [])
        }
    }

    @Test("提供同名子代理时抛出 duplicateName")
    func resolveThrowsForDuplicateName() {
        #expect(throws: SubagentIdentityError.duplicateName("explorer")) {
            _ = try SubagentIdentity.resolve(requested: "explorer", existing: ["explorer"])
        }
    }

    // MARK: - 载荷持久化

    @Test("名字随载荷往返")
    func payloadRoundTripsName() throws {
        let payload = SubagentTimeline.Payload(
            label: "Research",
            parentConversationID: UUID(),
            childConversationID: UUID(),
            jobID: "job-1",
            name: "explorer"
        )
        let decoded = try #require(
            SubagentTimeline.decodePayload(from: SubagentTimeline.metadata(for: payload))
        )
        #expect(decoded.name == "explorer")
        #expect(decoded == payload)
    }

    @Test("旧载荷没有 name 字段时解码为 nil，保持历史委托可读")
    func legacyPayloadWithoutNameDecodes() throws {
        let json = """
        {"label":"Legacy","parentConversationID":"\(UUID().uuidString)","childConversationID":"\(UUID().uuidString)","jobID":"job-old"}
        """
        let decoded = try #require(
            SubagentTimeline.decodePayload(from: [SubagentTimeline.payloadKey: json])
        )
        #expect(decoded.name == nil)
        #expect(decoded.label == "Legacy")
    }
}
