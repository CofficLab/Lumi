import LumiKernel
import SubAgentProviderPlugin
import Testing

@MainActor
@Suite("SubAgentProviderPlugin")
struct SubAgentProviderPluginTests {
    // subAgents(kernel:) 是同步的，传一个 bare LumiKernel()（其 toolManager 为 nil）
    // 不影响定义的返回。
    private let kernel = LumiKernel()

    @Test("插件元数据")
    func metadata() {
        let plugin = SubAgentProviderPlugin()
        #expect(!plugin.id.isEmpty)
        #expect(!plugin.name.isEmpty)
        #expect(plugin.policy == .alwaysOn)
        #expect(plugin.category == .agent)
        #expect(!plugin.pluginDescription.isEmpty)
    }

    @Test("贡献 4 个内置子 Agent")
    func contributesFourDefinitions() {
        let plugin = SubAgentProviderPlugin()
        let agents = plugin.subAgents(kernel: kernel)
        #expect(agents.count == 4)
    }

    @Test("所有子 Agent 都继承当前选中供应商")
    func allInheritSelectedProvider() {
        let plugin = SubAgentProviderPlugin()
        let agents = plugin.subAgents(kernel: kernel)
        #expect(agents.allSatisfy { $0.inheritsSelectedProvider == true })
    }

    @Test("所有子 Agent 的 providerID/modelID 留空（占位）")
    func pinnedIdentifiersBlank() {
        let plugin = SubAgentProviderPlugin()
        let agents = plugin.subAgents(kernel: kernel)
        #expect(agents.allSatisfy { $0.providerID.isEmpty })
        #expect(agents.allSatisfy { $0.modelID.isEmpty })
    }

    @Test("id 与 displayName 唯一")
    func uniqueIdentity() {
        let plugin = SubAgentProviderPlugin()
        let agents = plugin.subAgents(kernel: kernel)
        let ids = Set(agents.map(\.id))
        let names = Set(agents.map(\.displayName))
        #expect(ids.count == agents.count)
        #expect(names.count == agents.count)
    }

    @Test("预期 id 集合，且带 builtin- 前缀避免与 StepFun 同名 Agent 冲突")
    func expectedIds() {
        let plugin = SubAgentProviderPlugin()
        let ids = Set(plugin.subAgents(kernel: kernel).map(\.id))
        let expected: Set<String> = [
            "builtin-explore",
            "builtin-code-review",
            "builtin-bugfixer",
            "builtin-test-writer"
        ]
        #expect(ids == expected)
    }

    @Test("只读 Agent（Explore / Code Review）排除破坏性与副作用标签")
    func readOnlyAgentsExcludeDestructive() {
        let plugin = SubAgentProviderPlugin()
        let agents = plugin.subAgents(kernel: kernel)
        let readOnly = agents.filter {
            $0.id == "builtin-explore" || $0.id == "builtin-code-review"
        }
        #expect(readOnly.allSatisfy { $0.excludedTags.contains(.destructive) })
        #expect(readOnly.allSatisfy { $0.excludedTags.contains(.sideEffect) })
    }
}
