import Foundation
import Testing
import KitLLM
@testable import PluginLLMProviderCodex

@Suite("PluginLLMProviderCodex")
struct CodexProviderTests {
    @Test("plugin metadata and local provider registration")
    @MainActor
    func pluginMetadata() throws {
        let plugin = CodexLumiPlugin()
        #expect(plugin.id == "com.coffic.lumi.plugin.llm-provider.codex")
        #expect(plugin.order == 100)
        #expect(CodexProvider().providerInfo.isLocal)
    }

    @Test("exec arguments preserve Codex CLI flags")
    func execArguments() {
        let cli = CodexCLI(executablePath: "/tmp/codex")
        let args = cli.arguments(prompt: "hello", model: "gpt-5.5", reasoningEffort: "low")
        #expect(args.prefix(3) == ["-a", "never", "exec"])
        #expect(args.contains("model_reasoning_effort=\"low\""))
        #expect(args.last == "hello")
    }

    @Test("parser extracts response and usage")
    func parser() {
        let parsed = CodexOutputParser.parse("""
        {"type":"item.completed","item":{"type":"agent_message","text":"hello"}}
        {"type":"turn.completed","usage":{"input_tokens":12,"output_tokens":3}}
        """)
        #expect(parsed.agentMessages == ["hello"])
        #expect(parsed.inputTokens == 12)
        #expect(parsed.outputTokens == 3)
    }
}
