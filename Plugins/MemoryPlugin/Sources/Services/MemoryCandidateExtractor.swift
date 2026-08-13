import Foundation
import KernelLumi

/// 只提取高置信度的长期信息，不把普通任务内容写入记忆。
public enum MemoryCandidateExtractor {
    private static let explicitMarkers = [
        "记住", "请记住", "以后", "今后", "长期", "我偏好", "我喜欢", "我不喜欢",
        "不要再", "别再", "应该始终", "默认使用", "约定", "规定",
        "remember", "from now on", "going forward", "i prefer", "i like", "i don't like",
        "never", "always", "by default"
    ]

    private static let feedbackMarkers = [
        "不要再", "别再", "以后不要", "不应该", "你应该", "请不要",
        "never", "don't", "do not", "you should", "always"
    ]

    private static let sensitiveMarkers = [
        "password", "passwd", "token", "secret", "api key", "apikey", "private key",
        "密码", "口令", "令牌", "密钥", "私钥", "access key", "authorization:"
    ]

    public static func extract(
        from messages: [LumiChatMessage],
        projectPath: String?
    ) -> [MemoryCandidate] {
        guard let userMessage = messages.last(where: { $0.role == .user }) else { return [] }
        return extract(from: userMessage.content, projectPath: projectPath)
    }

    public static func extract(
        from text: String,
        projectPath: String?
    ) -> [MemoryCandidate] {
        let content = normalized(text)
        guard !content.isEmpty, content.count <= 2000 else { return [] }

        let lowercased = content.lowercased()
        guard explicitMarkers.contains(where: lowercased.contains) else { return [] }
        guard !sensitiveMarkers.contains(where: lowercased.contains) else { return [] }

        let isProject = projectPath != nil && ["项目", "仓库", "工作区", "project", "repository", "workspace"]
            .contains(where: lowercased.contains)
        let isFeedback = feedbackMarkers.contains(where: lowercased.contains)
        let type: MemoryType = isProject ? .project : (isFeedback ? .feedback : .user)
        let scope: MemoryScope = isProject ? .project(projectPath!) : .global

        let title = makeTitle(from: content)
        let id = makeID(type: type, title: title)
        let description = isFeedback
            ? "用户对 Agent 行为的长期指导：\(title)"
            : (isProject ? "项目长期约定：\(title)" : "用户长期偏好：\(title)")
        let storedContent = isFeedback
            ? "\(content)\n\n**How to apply:** 在后续对话中优先遵守这条用户指导。"
            : content

        return [MemoryCandidate(
            id: id,
            type: type,
            name: title,
            description: description,
            content: storedContent,
            scope: scope
        )]
    }

    private static func normalized(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    private static func makeTitle(from content: String) -> String {
        let title = content
            .replacingOccurrences(of: "请记住", with: "")
            .replacingOccurrences(of: "记住", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String(title.prefix(80)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func makeID(type: MemoryType, title: String) -> String {
        let ascii = title
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        if !ascii.isEmpty {
            return "auto-\(type.rawValue)-\(String(ascii.prefix(48)))"
        }

        let hash = title.utf8.reduce(UInt64(0xcbf29ce484222325)) { hash, byte in
            (hash ^ UInt64(byte)) &* 0x100000001b3
        }
        return "auto-\(type.rawValue)-\(String(format: "%016llx", hash))"
    }
}
