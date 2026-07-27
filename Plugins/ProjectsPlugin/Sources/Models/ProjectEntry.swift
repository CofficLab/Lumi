import Foundation

/// 项目条目
///
/// 表示一个已保存的项目，包含名称、路径、语言和最后使用时间。
public struct ProjectEntry: Sendable, Codable, Identifiable, Hashable {
    public var id: String { path }
    public let name: String
    public let path: String
    public let language: String?
    public let lastUsed: Date

    public init(name: String, path: String, language: String? = nil, lastUsed: Date = Date()) {
        self.name = name
        self.path = path
        self.language = language
        self.lastUsed = lastUsed
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(path)
    }

    public static func == (lhs: ProjectEntry, rhs: ProjectEntry) -> Bool {
        lhs.path == rhs.path
    }
}

/// 项目语言检测器
public enum ProjectLanguageDetector {
    public static func detect(at path: String) -> String? {
        let url = URL(fileURLWithPath: path)

        // Swift
        if FileManager.default.fileExists(atPath: url.appendingPathComponent("Package.swift").path) {
            return "swift"
        }

        // Rust
        if FileManager.default.fileExists(atPath: url.appendingPathComponent("Cargo.toml").path) {
            return "rust"
        }

        // Node.js
        if FileManager.default.fileExists(atPath: url.appendingPathComponent("package.json").path) {
            return "javascript"
        }

        // Python
        if FileManager.default.fileExists(atPath: url.appendingPathComponent("pyproject.toml").path) ||
           FileManager.default.fileExists(atPath: url.appendingPathComponent("setup.py").path) {
            return "python"
        }

        // Go
        if FileManager.default.fileExists(atPath: url.appendingPathComponent("go.mod").path) {
            return "go"
        }

        return nil
    }
}