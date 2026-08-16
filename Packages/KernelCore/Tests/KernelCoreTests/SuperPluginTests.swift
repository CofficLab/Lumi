import Testing
@testable import KernelCore

/// SuperPlugin 协议的基础验证。
@Suite("SuperPlugin")
@MainActor
struct SuperPluginTests {

    private final class MockPlugin: SuperPlugin {
        let id: String
        init(id: String) { self.id = id }
    }

    @Test("SuperPlugin 可被实现并通过协议访问")
    func pluginAccessibleThroughProtocol() {
        let plugin: any SuperPlugin = MockPlugin(id: "test.plugin")

        #expect(plugin.id == "test.plugin")
        #expect(plugin.metadata.id == "test.plugin")
        #expect(plugin.metadata.policy == .enabledByDefault)
    }

    @Test("不同插件实例 id 独立")
    func pluginIDsAreDistinct() {
        let a: any SuperPlugin = MockPlugin(id: "a")
        let b: any SuperPlugin = MockPlugin(id: "b")

        #expect(a.id != b.id)
        #expect(a.id == "a")
        #expect(b.id == "b")
    }
}
