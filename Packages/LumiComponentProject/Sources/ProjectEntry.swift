import Foundation

/// 内核级项目条目模型，所有插件共享。
public struct ProjectEntry: Codable, Equatable, Identifiable, Sendable {
    public var id: String { path }

    /// 项目所属的编程语言/技术栈。
    ///
    /// 用于 per-request 动态注入：插件在 `agentTools(context:)` 内可据此判断要不要
    /// 返回工具（例如只在 `.swift` 项目下暴露 Swift 工具）。由 `ProjectLanguageDetector`
    /// 在打开项目时扫描 marker 文件（`Package.swift` / `go.mod` / `Cargo.toml` 等）填充。
    /// `unknown` 表示未识别，插件应自行决定如何处理（通常等价于"全量返回"）。
    public enum Language: String, Codable, Sendable, CaseIterable {
        case swift
        case go
        case rust
        case javascript
        case typescript
        case python
        case unknown
    }

    public let name: String
    public let path: String
    public let language: Language
    public let lastUsed: Date

    /// - Parameter language: 项目语言。默认 `.unknown` 以保持向后兼容——旧调用点
    ///   （如插件）不传此参数时退化为"未识别"，不影响编译。
    public init(name: String, path: String, language: Language = .unknown, lastUsed: Date = Date()) {
        self.name = name
        self.path = path
        self.language = language
        self.lastUsed = lastUsed
    }

    // MARK: - Codable（向后兼容旧数据）

    private enum CodingKeys: String, CodingKey {
        case name, path, language, lastUsed
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try c.decode(String.self, forKey: .name)
        self.path = try c.decode(String.self, forKey: .path)
        // 旧数据无 language 字段，或值无法解析时，降级为 .unknown，避免解码失败丢数据。
        self.language = (try c.decodeIfPresent(Language.self, forKey: .language)) ?? .unknown
        self.lastUsed = try c.decode(Date.self, forKey: .lastUsed)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(name, forKey: .name)
        try c.encode(path, forKey: .path)
        try c.encode(language, forKey: .language)
        try c.encode(lastUsed, forKey: .lastUsed)
    }
}
