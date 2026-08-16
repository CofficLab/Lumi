import AgentToolKit
import Foundation
import Testing
@testable import ProviderToolManager

// MARK: - 注册 / 分组 / 删除

@MainActor
struct ToolManagerRegistrationTests {

    @Test("add 与 allTools 保持注册顺序")
    func addAndOrder() {
        let manager = DefaultToolManagerProviding()
        manager.add(MockTool(name: "first"))
        manager.add(MockTool(name: "second"))

        #expect(manager.allTools().map(\.name) == ["first", "second"])
    }

    @Test("add 相同名称工具迁移归属且不重复")
    func addMigratesOwnership() {
        let manager = DefaultToolManagerProviding()
        manager.add(MockTool(name: "tool"), pluginID: "plugin-a")
        manager.add(MockTool(name: "tool"), pluginID: "plugin-b")

        let groups = manager.toolsGroupedByPlugin()
        #expect(groups.count == 1)
        #expect(groups.first?.pluginID == "plugin-b")
        #expect(manager.allTools().count == 1)
    }

    @Test("toolsGroupedByPlugin 按插件分组、组内保持顺序")
    func groupedByPlugin() {
        let manager = DefaultToolManagerProviding()
        manager.add(MockTool(name: "a1"), pluginID: "p1")
        manager.add(MockTool(name: "b1"), pluginID: "p2")
        manager.add(MockTool(name: "a2"), pluginID: "p1")
        manager.add(MockTool(name: "standalone"))

        let groups = manager.toolsGroupedByPlugin()
        #expect(groups.map(\.pluginID) == ["p1", "p2", "Built-in"])
        #expect(groups[0].tools.map(\.name) == ["a1", "a2"])
        #expect(groups[2].tools.map(\.name) == ["standalone"])
    }

    @Test("remove 与 removeAll 清理分组索引")
    func removeAndRemoveAll() {
        let manager = DefaultToolManagerProviding()
        manager.add(MockTool(name: "a"), pluginID: "p1")
        manager.add(MockTool(name: "b"), pluginID: "p2")

        manager.remove(id: "a")
        #expect(manager.tool(named: "a") == nil)
        #expect(manager.allTools().map(\.name) == ["b"])
        #expect(manager.toolsGroupedByPlugin().map(\.pluginID) == ["p2"])

        manager.removeAll()
        #expect(manager.allTools().isEmpty)
        #expect(manager.toolsGroupedByPlugin().isEmpty)
    }
}

// MARK: - 描述 / 风险 / 查找

@MainActor
struct ToolManagerLookupTests {

    @Test("displayDescription 使用工具展示名与参数")
    func displayDescription() {
        let manager = DefaultToolManagerProviding()
        manager.add(MockTool(name: "read", displayName: "读取"), pluginID: "p")

        let call = makeToolCall(name: "read", arguments: ["path": "/tmp/a.txt"])
        #expect(manager.displayDescription(for: call) == "读取 /tmp/a.txt")
    }

    @Test("displayDescription 无法解析时返回 nil")
    func displayDescriptionNil() {
        let manager = DefaultToolManagerProviding()
        manager.add(MockTool(name: "read"), pluginID: "p")

        #expect(manager.displayDescription(for: makeToolCall(name: "missing")) == nil)
        // 非对象 JSON 参数 → nil
        let bad = ToolCall(id: "c", name: "read", arguments: "[1,2,3]")
        #expect(manager.displayDescription(for: bad) == nil)
    }

    @Test("riskLevel 解析工具自身风险")
    func riskLevel() {
        let manager = DefaultToolManagerProviding()
        manager.add(MockTool(name: "safe", risk: .safe), pluginID: "p")
        manager.add(MockTool(name: "risky", risk: .high), pluginID: "p")

        #expect(manager.riskLevel(for: makeToolCall(name: "safe")) == .safe)
        #expect(manager.riskLevel(for: makeToolCall(name: "risky")) == .high)
        #expect(manager.riskLevel(for: makeToolCall(name: "missing")) == nil)
    }
}

// MARK: - 参数编解码

struct ToolArgumentCodingTests {

    @Test("decode 空字符串得到空字典")
    func decodeEmpty() throws {
        let result = try ToolArgumentCoding.decode("")
        #expect(result.isEmpty)
    }

    @Test("decode 保留 JSON 原始类型")
    func decodeTypes() throws {
        let result = try ToolArgumentCoding.decode(#"{"s":"hi","n":42,"b":true,"arr":[1,2],"obj":{"k":"v"}}"#)
        #expect((result["s"]?.value as? String) == "hi")
        #expect((result["n"]?.value as? NSNumber)?.intValue == 42)
        #expect((result["b"]?.value as? Bool) == true)
        #expect((result["arr"]?.value as? [Any])?.count == 2)
        #expect((result["obj"]?.value as? [String: Any])?["k"] as? String == "v")
    }

    @Test("decode 非对象 JSON 抛错")
    func decodeNonObjectThrows() {
        #expect(throws: (any Error).self) {
            _ = try ToolArgumentCoding.decode("[1,2]")
        }
    }

    @Test("encode 往返一致")
    func encodeRoundTrip() throws {
        let args = try ToolArgumentCoding.decode(#"{"path":"/tmp/a"}"#)
        let json = ToolArgumentCoding.encode(args)
        let decoded = try ToolArgumentCoding.decode(json)
        #expect((decoded["path"]?.value as? String) == "/tmp/a")
    }
}
