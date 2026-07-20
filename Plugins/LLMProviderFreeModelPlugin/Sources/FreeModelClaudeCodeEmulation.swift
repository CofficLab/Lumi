import CryptoKit
import Foundation
import LumiCoreMessage
import LumiKernel

/// 按 Claude Code 源码模拟 Anthropic 网关请求（独立实现，不与 Zhipu 共享）。
enum FreeModelClaudeCodeEmulation {
    /// 与本地 `claude --version` 对齐，网关可能校验版本格式。
    static let version = "2.1.1"

    private static let fingerprintSalt = "59cf53e54c78"
    private static let cliPrefix = "You are Claude Code, Anthropic's official CLI for Claude."
    private static let sessionDefaultsKey = "freemodel.claude_code.session_id"
    private static let deviceDefaultsKey = "freemodel.claude_code.device_id"

    static let sessionID: String = persistedUUID(defaultsKey: sessionDefaultsKey)
    static let deviceID: String = persistedUUID(defaultsKey: deviceDefaultsKey)

    static func userAgent() -> String {
        "claude-cli/\(version) (external, cli)"
    }

    static func anthropicBetaHeader(for model: String) -> String {
        var betas = ["claude-code-20250219"]
        if !model.localizedCaseInsensitiveContains("haiku") {
            betas.append(contentsOf: [
                "interleaved-thinking-2025-05-14",
                "context-management-2025-06-27",
                "prompt-caching-scope-2026-01-05",
            ])
        }
        return betas.joined(separator: ",")
    }

    static func computeFingerprint(firstUserMessageText: String) -> String {
        let indices = [4, 7, 20]
        let chars = indices.map { index -> Character in
            guard index < firstUserMessageText.count else { return "0" }
            let stringIndex = firstUserMessageText.index(firstUserMessageText.startIndex, offsetBy: index)
            return firstUserMessageText[stringIndex]
        }
        let input = fingerprintSalt + String(chars) + version
        let digest = SHA256.hash(data: Data(input.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return String(hex.prefix(3))
    }

    static func attributionHeader(fingerprint: String) -> String {
        let ccVersion = "\(version).\(fingerprint)"
        // cch=00000 为 Claude Code 原生占位符；非 Bun 客户端无法生成真实 token，但部分网关仅校验格式。
        return "x-anthropic-billing-header: cc_version=\(ccVersion); cc_entrypoint=cli; cch=00000;"
    }

    static func metadata() -> [String: Any] {
        let userID: [String: String] = [
            "device_id": deviceID,
            "account_uuid": "",
            "session_id": sessionID,
        ]
        guard
            let data = try? JSONSerialization.data(withJSONObject: userID),
            let json = String(data: data, encoding: .utf8)
        else {
            return [:]
        }
        return ["user_id": json]
    }

    static func systemBlocks(
        fingerprint: String,
        existingSystemParts: [String]
    ) -> [[String: Any]] {
        var blocks: [[String: Any]] = [
            ["type": "text", "text": attributionHeader(fingerprint: fingerprint)],
            ["type": "text", "text": cliPrefix],
        ]
        for part in existingSystemParts where !part.isEmpty {
            blocks.append(["type": "text", "text": part])
        }
        return blocks
    }

    static func firstUserMessageText(from messages: [LumiChatMessage]) -> String {
        for message in messages where message.role == .user {
            let trimmed = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return message.content
            }
        }
        return ""
    }

    static func isGatewayRejection(_ content: String) -> Bool {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed == "Please use Claude Code CLI"
            || trimmed.localizedCaseInsensitiveContains("please use claude code cli")
    }

    private static func persistedUUID(defaultsKey: String) -> String {
        if let existing = UserDefaults.standard.string(forKey: defaultsKey), !existing.isEmpty {
            return existing
        }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: defaultsKey)
        return id
    }
}
