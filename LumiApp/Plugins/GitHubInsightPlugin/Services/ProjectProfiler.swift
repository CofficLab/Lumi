import Foundation

/// Builds a technology profile for a local project by inspecting common manifest files.
///
/// The profiler reads package manifests and README content to infer language,
/// frameworks, dependencies, project type, keywords, and platform hints used by
/// GitHub ecosystem discovery.
struct GitHubInsightProjectProfiler {
    /// File system helper used to inspect project files.
    private let fileManager = FileManager.default

    /// Creates a project profile for a readable local project directory.
    ///
    /// - Parameter projectPath: Local project root path.
    /// - Returns: An inferred project profile, or `nil` when the path is not a directory.
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

    /// Reads a JSON object from disk.
    private func readJSON(_ url: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return json
    }

    /// Extracts dependency names from selected package JSON keys.
    private func dependencyNames(from json: [String: Any], keys: [String]) -> [String] {
        keys.flatMap { key -> [String] in
            guard let dependencies = json[key] as? [String: Any] else { return [] }
            return Array(dependencies.keys)
        }
    }

    /// Detects well-known JavaScript frameworks from dependency names.
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

    /// Extracts Swift package dependency repository names from `Package.swift`.
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

    /// Extracts CocoaPods dependency names from a `Podfile`.
    private func podDependencies(at url: URL) -> [String] {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return regexMatches(pattern: #"pod\s+['"]([^'"]+)['"]"#, text: text)
    }

    /// Extracts the platform declaration from a `Podfile`.
    private func podPlatform(at url: URL) -> String? {
        guard let text = try? String(contentsOf: url, encoding: .utf8),
              let value = regexMatches(pattern: #"platform\s+:(\w+),\s*['"]([^'"]+)['"]"#, text: text).first else {
            return nil
        }
        return value
    }

    /// Extracts direct Go module requirements from `go.mod`.
    private func goDependencies(at url: URL) -> [String] {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return text.split(separator: "\n").compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("require ") else { return nil }
            return trimmed.replacingOccurrences(of: "require ", with: "").split(separator: " ").first.map(String.init)
        }
    }

    /// Extracts dependency names from the `[dependencies]` section of a TOML file.
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

    /// Extracts Python dependency names from supported Python manifest files.
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

    /// Extracts a short description and frequent keywords from README content.
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

    /// Infers the broad project type from files, frameworks, and dependencies.
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

    /// Returns the first capture group for all matches of a regular expression.
    private func regexMatches(pattern: String, text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsText = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: nsText.length)).compactMap { match in
            guard match.numberOfRanges > 1 else { return nil }
            return nsText.substring(with: match.range(at: 1))
        }
    }

    /// Words ignored when deriving README keywords.
    private static let stopWords: Set<String> = [
        "the", "and", "for", "with", "from", "this", "that", "you", "are", "was", "were",
        "have", "has", "can", "will", "your", "our", "use", "using", "into", "about",
        "一个", "项目", "使用", "支持"
    ]
}
