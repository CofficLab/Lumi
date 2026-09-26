import Foundation
import Testing
@testable import FactoryLumiACP
import KernelCore

@Suite("ACPBootstrapError Tests")
struct ACPBootstrapErrorTests {

    @Test("pluginNotFound case 的 description 正确")
    func pluginNotFoundDescription() {
        let error = ACPBootstrapError.pluginNotFound
        #expect(error.description == "plugin 'acp' not found")
        #expect(error.errorDescription == "plugin 'acp' not found")
    }

    @Test("ACPBootstrapError 符合 Error 协议")
    func isError() {
        let error: Error = ACPBootstrapError.pluginNotFound
        #expect(error is ACPBootstrapError)
        #expect((error as? ACPBootstrapError) == .pluginNotFound)
    }

    @Test("ACPBootstrapError 可被抛出并捕获")
    func canThrowAndCatch() {
        do {
            throw ACPBootstrapError.pluginNotFound
        } catch let error as ACPBootstrapError {
            #expect(error == .pluginNotFound)
            #expect(error.description.contains("acp"))
        } catch {
            Issue.record("Wrong error type: \(error)")
        }
    }
}

@Suite("ACPPluginFactory Tests")
@MainActor
struct ACPPluginFactoryTests {

    @Test("makePlugins 返回非空插件列表")
    func makePluginsReturnsNonEmpty() {
        let factory = ACPPluginFactory()
        let plugins = factory.makePlugins()

        #expect(!plugins.isEmpty)
        // ACP 装配包含约 58 个插件
        #expect(plugins.count >= 50)
    }

    @Test("插件列表包含 ACP 核心插件")
    func containsCorePlugins() {
        let factory = ACPPluginFactory()
        let plugins = factory.makePlugins()

        let ids = plugins.map { $0.id }
        // 核心 ACP 插件必须在列
        #expect(ids.contains("acp"))
        #expect(ids.contains("com.coffic.lumi.plugin.llm-manager"))
        #expect(ids.contains("com.coffic.lumi.plugin.tool-manager"))
        #expect(ids.contains("com.coffic.lumi.plugin.agent-loop"))
        #expect(ids.contains("com.coffic.lumi.plugin.conversation-manager"))
        #expect(ids.contains("com.coffic.lumi.plugin.message-manager"))
        #expect(ids.contains("com.coffic.lumi.plugin.mcp"))
    }

    @Test("插件列表包含 LLM 供应商插件")
    func containsLLMProviders() {
        let factory = ACPPluginFactory()
        let plugins = factory.makePlugins()

        let ids = plugins.map { $0.id }
        // 主要 LLM 供应商
        #expect(ids.contains("com.coffic.lumi.plugin.llm-provider.openai"))
        #expect(ids.contains("com.coffic.lumi.plugin.llm-provider.anthropic"))
        #expect(ids.contains("com.coffic.lumi.plugin.llm-provider.deepseek"))
        #expect(ids.contains("com.coffic.lumi.plugin.llm-provider.zhipu"))
    }

    @Test("插件 ID 唯一无重复")
    func pluginIDsAreUnique() {
        let factory = ACPPluginFactory()
        let plugins = factory.makePlugins()

        let ids = plugins.map { $0.id }
        #expect(ids.count == Set(ids).count, "Duplicate plugin IDs found")
    }

    @Test("每次调用 makePlugins 返回新实例")
    func makePluginsReturnsFreshInstances() {
        let factory = ACPPluginFactory()
        let first = factory.makePlugins()
        let second = factory.makePlugins()

        // 数量相同但是不同的实例数组
        #expect(first.count == second.count)
        // 第一个插件不应是同一个对象引用
        #expect(first[0] !== second[0])
    }
}

@Suite("PluginDataMigrationCoordinator Tests")
@MainActor
struct PluginDataMigrationCoordinatorTests {

    @Test("currentMajorVersion 为正整数")
    func currentMajorVersionIsPositive() {
        #expect(PluginDataMigrationCoordinator.currentMajorVersion > 0)
        #expect(PluginDataMigrationCoordinator.currentMajorVersion == 6)
    }
}

@Suite("PluginFactory Protocol Tests")
@MainActor
struct PluginFactoryProtocolTests {

    @Test("自定义 PluginFactory 实现可被 KernelFactory 接受")
    func customPluginFactoryConformance() {
        struct CustomFactory: PluginFactory {
            func makePlugins() -> [any SuperPlugin] {
                []
            }
        }

        let factory: any PluginFactory = CustomFactory()
        #expect(factory.makePlugins().isEmpty)
    }
}
