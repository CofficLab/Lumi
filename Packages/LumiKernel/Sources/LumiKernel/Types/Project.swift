import Foundation

/// 项目信息
public struct ProjectInfo: Sendable, Codable {
    public let name: String
    public let path: String
    public let language: String?

    public init(name: String, path: String, language: String? = nil) {
        self.name = name
        self.path = path
        self.language = language
    }
}

/// 内核级项目条目模型，所有插件共享。
public struct ProjectEntry: Codable, Equatable, Identifiable, Sendable {
    public var id: String { path }

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

    public init(name: String, path: String, language: Language = .unknown, lastUsed: Date = Date()) {
        self.name = name
        self.path = path
        self.language = language
        self.lastUsed = lastUsed
    }

    private enum CodingKeys: String, CodingKey {
        case name, path, language, lastUsed
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try c.decode(String.self, forKey: .name)
        self.path = try c.decode(String.self, forKey: .path)
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
