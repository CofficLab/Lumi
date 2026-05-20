import Foundation

/// 通过检查常见清单文件为本地项目构建技术画像。
///
/// 画像器会读取包清单和 README 内容，推断 GitHub 生态发现所需的语言、
/// 框架、依赖、项目类型、关键词和平台提示。
struct GitHubInsightProjectProfiler {
    /// 用于检查项目文件的文件系统工具。
    private let fileManager = FileManager.default

    /// 为可读取的本地项目目录创建项目画像。
    ///
    /// - Parameter projectPath: 本地项目根目录路径。
    /// - Returns: 推断出的项目画像；当路径不是目录时返回 `nil`。
    func profile(projectPath: String) -> GitHubInsightProjectProfile? {
        let root = URL(fileURLWithPath: projectPath).standardizedFileURL
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: root.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return nil
        }

        var dependencies = Set<String>()
        var frameworks = Set<String>()
        var languages: [String: Int] = [:]
        var platform: String?

        if let package = readJSON(root.appendingPathComponent("package.json")) {
            languages["TypeScript", default: 0] += 2
            let packageDependencies = dependencyNames(from: package, keys: ["dependencies", "devDependencies"])
            dependencies.formUnion(packageDependencies)
            frameworks.formUnion(detectJSFrameworks(from: packageDependencies))
        }

        if fileManager.fileExists(atPath: root.appendingPathComponent("Package.swift").path) {
            languages["Swift", default: 0] += 3
            dependencies.formUnion(swiftPackageDependencies(at: root.appendingPathComponent("Package.swift")))
        }

        if fileManager.fileExists(atPath: root.appendingPathComponent("Podfile").path) {
            languages["Swift", default: 0] += 2
            dependencies.formUnion(podDependencies(at: root.appendingPathComponent("Podfile")))
            platform = platform ?? podPlatform(at: root.appendingPathComponent("Podfile"))
        }

        if fileManager.fileExists(atPath: root.appendingPathComponent("go.mod").path) {
            languages["Go", default: 0] += 3
            dependencies.formUnion(goDependencies(at: root.appendingPathComponent("go.mod")))
        }

        if fileManager.fileExists(atPath: root.appendingPathComponent("Cargo.toml").path) {
            languages["Rust", default: 0] += 3
            dependencies.formUnion(tomlDependencyNames(at: root.appendingPathComponent("Cargo.toml")))
        }

        if fileManager.fileExists(atPath: root.appendingPathComponent("pyproject.toml").path) ||
            fileManager.fileExists(atPath: root.appendingPathComponent("requirements.txt").path) {
            languages["Python", default: 0] += 3
            dependencies.formUnion(pythonDependencies(at: root))
        }

        if fileManager.fileExists(atPath: root.appendingPathComponent("build.gradle").path) ||
            fileManager.fileExists(atPath: root.appendingPathComponent("pom.xml").path) {
            languages["Kotlin", default: 0] += 2
        }

        let readme = readReadme(at: root)
        let description = readme.description
        let keywords = readme.keywords
        let inferredType = inferProjectType(root: root, frameworks: frameworks, dependencies: dependencies)

        if frameworks.contains("SwiftUI") || dependencies.contains("SwiftUI") {
            platform = platform ?? "Apple platforms"
        }

        return GitHubInsightProjectProfile(
            projectPath: root.path,
            primaryLanguage: languages.sorted { $0.value > $1.value }.first?.key,
            frameworks: Array(frameworks).sorted(),
            dependencies: Array(dependencies).sorted(),
            projectType: inferredType,
            keywords: keywords,
            description: description,
            platform: platform
        )
    }

    /// 从磁盘读取 JSON 对象。
    private func readJSON(_ url: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return json
    }

    /// 从选定的 package JSON key 中提取依赖名称。
    private func dependencyNames(from json: [String: Any], keys: [String]) -> [String] {
        keys.flatMap { key -> [String] in
            guard let dependencies = json[key] as? [String: Any] else { return [] }
            return Array(dependencies.keys)
        }
    }

    /// 根据依赖名称检测常见 JavaScript 框架。
    private func detectJSFrameworks(from dependencies: [String]) -> [String] {
        let map: [String: String] = [
            "react": "React",
            "vue": "Vue",
            "next": "Next.js",
            "nuxt": "Nuxt",
            "svelte": "Svelte",
            "vite": "Vite",
            "electron": "Electron"
        ]
        return dependencies.compactMap { map[$0.lowercased()] }
    }

    /// 从 `Package.swift` 提取 Swift 包依赖仓库名称。
    private func swiftPackageDependencies(at url: URL) -> [String] {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        var result = Set<String>()
        let pattern = #"url:\s*"[^"]*/([^/"]+?)(?:\.git)?""#
        for match in regexMatches(pattern: pattern, text: text) {
            result.insert(match)
        }
        if text.contains("SwiftUI") { result.insert("SwiftUI") }
        if text.contains("Combine") { result.insert("Combine") }
        return Array(result)
    }

    /// 从 `Podfile` 提取 CocoaPods 依赖名称。
    private func podDependencies(at url: URL) -> [String] {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return regexMatches(pattern: #"pod\s+['"]([^'"]+)['"]"#, text: text)
    }

    /// 从 `Podfile` 提取平台声明。
    private func podPlatform(at url: URL) -> String? {
        guard let text = try? String(contentsOf: url, encoding: .utf8),
              let value = regexMatches(pattern: #"platform\s+:(\w+),\s*['"]([^'"]+)['"]"#, text: text).first else {
            return nil
        }
        return value
    }

    /// 从 `go.mod` 提取直接 Go 模块依赖。
    private func goDependencies(at url: URL) -> [String] {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return text.split(separator: "\n").compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("require ") else { return nil }
            return trimmed.replacingOccurrences(of: "require ", with: "").split(separator: " ").first.map(String.init)
        }
    }

    /// 从 TOML 文件的 `[dependencies]` 段提取依赖名称。
    private func tomlDependencyNames(at url: URL) -> [String] {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        var inDependencies = false
        var names: [String] = []
        for line in text.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("[") {
                inDependencies = trimmed == "[dependencies]"
                continue
            }
            if inDependencies, let name = trimmed.split(separator: "=").first {
                names.append(String(name).trimmingCharacters(in: .whitespaces))
            }
        }
        return names
    }

    /// 从支持的 Python 清单文件中提取 Python 依赖名称。
    private func pythonDependencies(at root: URL) -> [String] {
        var result: [String] = []
        let requirements = root.appendingPathComponent("requirements.txt")
        if let text = try? String(contentsOf: requirements, encoding: .utf8) {
            result += text.split(separator: "\n").compactMap { line in
                let clean = line.split(separator: "#").first?.trimmingCharacters(in: .whitespaces) ?? ""
                guard !clean.isEmpty else { return nil }
                return clean.split(whereSeparator: { "=<>~ ".contains($0) }).first.map(String.init)
            }
        }
        return result
    }

    /// 从 README 内容中提取简短描述和高频关键词。
    private func readReadme(at root: URL) -> (description: String, keywords: [String]) {
        let candidates = ["README.md", "README_zh.md", "Readme.md", "readme.md"]
        guard let url = candidates.map({ root.appendingPathComponent($0) }).first(where: { fileManager.fileExists(atPath: $0.path) }),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return ("", [])
        }
        let lines = text.split(separator: "\n").map(String.init)
        let description = lines.first { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            return !trimmed.isEmpty && !trimmed.hasPrefix("#") && !trimmed.hasPrefix("!")
        } ?? lines.first?.replacingOccurrences(of: "#", with: "").trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let words = text.lowercased()
            .replacingOccurrences(of: #"[^a-z0-9\-\+\.#]+"#, with: " ", options: .regularExpression)
            .split(separator: " ")
            .map(String.init)
            .filter { $0.count >= 3 && !Self.stopWords.contains($0) }
        let top = Dictionary(grouping: words, by: { $0 })
            .mapValues(\.count)
            .sorted { $0.value > $1.value }
            .prefix(12)
            .map(\.key)
        return (String(description.prefix(240)), Array(top))
    }

    /// 根据文件、框架和依赖推断项目的大致类型。
    private func inferProjectType(root: URL, frameworks: Set<String>, dependencies: Set<String>) -> GitHubInsightProjectType {
        if frameworks.contains("SwiftUI") || fileManager.fileExists(atPath: root.appendingPathComponent("Podfile").path) {
            return .mobile
        }
        if dependencies.contains("react") || dependencies.contains("vue") || dependencies.contains("next") || fileManager.fileExists(atPath: root.appendingPathComponent("public").path) {
            return .web
        }
        if fileManager.fileExists(atPath: root.appendingPathComponent("Sources").path) {
            return .sdk
        }
        if fileManager.fileExists(atPath: root.appendingPathComponent("bin").path) {
            return .cli
        }
        return .unknown
    }

    /// 返回正则表达式所有匹配项的第一个捕获组。
    private func regexMatches(pattern: String, text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsText = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: nsText.length)).compactMap { match in
            guard match.numberOfRanges > 1 else { return nil }
            return nsText.substring(with: match.range(at: 1))
        }
    }

    /// 从 README 派生关键词时忽略的词。
    private static let stopWords: Set<String> = [
        "the", "and", "for", "with", "from", "this", "that", "you", "are", "was", "were",
        "have", "has", "can", "will", "your", "our", "use", "using", "into", "about",
        "一个", "项目", "使用", "支持"
    ]
}
