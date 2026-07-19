import Foundation
import LumiKernel
import Testing
@testable import LLMProviderCodexPlugin

@Suite("PluginLLMProviderCodex")
struct CodexProviderTests {
    @Test("plugin metadata registers codex provider")
    func pluginMetadata() {
        #expect(CodexPlugin.id == "LLMProviderCodex")
        #expect(CodexPlugin.displayName == "Codex CLI")
        #expect(CodexPlugin.iconName == "terminal")
        #expect(CodexPlugin.category == .llmProvider)
        #expect(CodexPlugin.order == 11)
        #expect(CodexPlugin.shared.llmProviderType()?.id == "codex")
    }

    @Test("provider metadata is stable")
    func providerMetadata() {
        #expect(CodexProvider.id == "codex")
        #expect(CodexProvider.displayName == "Codex")
        #expect(CodexProvider.shortName == "CX")
        #expect(CodexProvider.apiKeyStorageKey == "")
        #expect(CodexProvider.defaultModel == "gpt-5.5")
        #expect(CodexProvider.availableModels == ["gpt-5.5", "gpt-5.4-mini"])
    }

    @Test("exec arguments put approval flag before exec subcommand")
    func execArgumentsPutApprovalFlagBeforeExec() {
        let cli = CodexCLI(executablePath: "/tmp/codex")
        let args = cli.arguments(prompt: "hello", model: "gpt-5.5")

        #expect(args == [
            "-a", "never",
            "exec",
            "--json",
            "-m", "gpt-5.5",
            "-s", "workspace-write",
            "--skip-git-repo-check",
            "hello"
        ])
        #expect(args.firstIndex(of: "-a")! < args.firstIndex(of: "exec")!)
        #expect(args.contains("--skip-git-repo-check"))
    }

    @Test("path candidates include common Homebrew locations and PATH")
    func pathCandidatesIncludeCommonLocationsAndPath() {
        let candidates = CodexCLI.pathCandidates(environment: ["PATH": "/custom/bin:/opt/homebrew/bin"])

        #expect(candidates.prefix(2) == ["/opt/homebrew/bin/codex", "/usr/local/bin/codex"])
        #expect(candidates.contains("/custom/bin/codex"))
        #expect(candidates.filter { $0 == "/opt/homebrew/bin/codex" }.count == 1)
    }

    @Test("parser extracts agent message and usage from item.completed JSONL")
    func parserExtractsAgentMessageAndUsage() {
        let output = """
        {"type":"thread.started","thread_id":"abc"}
        {"type":"item.completed","item":{"type":"agent_message","text":"hello"}}
        {"type":"turn.completed","usage":{"input_tokens":12,"output_tokens":3}}
        """

        let parsed = CodexOutputParser.parse(output)

        #expect(parsed.agentMessages == ["hello"])
        #expect(parsed.inputTokens == 12)
        #expect(parsed.outputTokens == 3)
        #expect(parsed.errors.isEmpty)
    }

    @Test("parser ignores reconnecting errors but keeps final failures")
    func parserIgnoresReconnectAndKeepsFailure() {
        let output = """
        {"type":"error","message":"Reconnecting... 2/5 (request timed out)"}
        {"type":"error","message":"{\\"detail\\":\\"The 'gpt-5' model is not supported when using Codex with a ChatGPT account.\\"}"}
        {"type":"turn.failed","error":{"message":"model unsupported"}}
        """

        let parsed = CodexOutputParser.parse(output)

        #expect(parsed.errors == [
            "{\"detail\":\"The 'gpt-5' model is not supported when using Codex with a ChatGPT account.\"}",
            "model unsupported"
        ])
        #expect(parsed.failedMessage == "model unsupported")
    }

    @Test("parser keeps non JSON stderr lines for CLI argument failures")
    func parserKeepsNonJSONLines() {
        let output = """
        error: unexpected argument '-a' found

          tip: to pass '-a' as a value, use '-- -a'
        """

        let parsed = CodexOutputParser.parse(output)

        #expect(parsed.agentMessages.isEmpty)
        #expect(parsed.nonJSONLines.first == "error: unexpected argument '-a' found")
    }

    @Test("prompt builder preserves sendable conversation turns")
    func promptBuilderPreservesConversationTurns() {
        let conversationId = UUID()
        let messages = [
            ChatMessage(role: .system, conversationId: conversationId, content: "internal"),
            ChatMessage(role: .user, conversationId: conversationId, content: "one"),
            ChatMessage(role: .assistant, conversationId: conversationId, content: "two"),
            ChatMessage(role: .tool, conversationId: conversationId, content: "tool result"),
            ChatMessage(role: .error, conversationId: conversationId, content: "do not send"),
        ]

        let prompt = CodexProvider.buildPrompt(from: messages, systemPrompt: "sys")

        #expect(prompt == """
        [System] sys

        [User] one

        [Assistant] two

        [Tool] tool result
        """)
    }

    @Test("provider reports missing CLI through local model state")
    func providerReportsMissingCLI() async {
        let provider = CodexProvider(cli: CodexCLI(executablePath: "/tmp/definitely-missing-codex"))

        let state = await provider.getModelState()

        #expect(state == .error("未找到 codex CLI: /tmp/definitely-missing-codex"))
    }

    @Test("provider drains large codex JSON output")
    func providerDrainsLargeCodexJSONOutput() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("codex-provider-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let executableURL = directory.appendingPathComponent("codex")
        try """
        #!/bin/sh
        i=1
        while [ "$i" -le 300 ]; do
          printf '{"type":"item.completed","item":{"type":"agent_message","text":"message-%03d-%0512d"}}\\n' "$i" 0
          printf '{"type":"trace","message":"stderr-%03d-%0512d"}\\n' "$i" 0 >&2
          i=$((i + 1))
        done
        printf '{"type":"turn.completed","usage":{"input_tokens":12,"output_tokens":300}}\\n'
        """.write(to: executableURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executableURL.path)

        let provider = CodexProvider(cli: CodexCLI(executablePath: executableURL.path))
        let conversationId = UUID()
        let message = try await provider.sendMessage(
            messages: [ChatMessage(role: .user, conversationId: conversationId, content: "hello")],
            model: CodexProvider.defaultModel,
            tools: nil,
            systemPrompt: nil,
            images: []
        )

        #expect(message.content.contains("message-300-"))
        #expect(message.inputTokens == 12)
        #expect(message.outputTokens == 300)
    }
}
