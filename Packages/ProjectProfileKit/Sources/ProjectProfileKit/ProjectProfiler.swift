import Foundation

/// 通过检查常见清单文件为本地项目构建技术画像。
///
/// 画像器会读取包清单和 README 内容，推断上层功能可复用的语言、框架、
/// 依赖、项目类型、关键词和平台提示。
public struct ProjectProfiler {
    /// 用于检查项目文件的文件系统工具。
    private let fileManager: FileManager

    /// 创建项目画像器。
    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    /// 为可读取的本地项目目录创建项目画像。
    ///
    /// - Parameter projectPath: 本地项目根目录路径。
    /// - Returns: 推断出的项目画像；当路径不是目录时返回 `nil`。
    public func profile(projectPath: String) -> ProjectProfile? {
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

        if containsXcodeProject(at: root) {
            languages["Swift", default: 0] += 4
            platform = platform ?? "Apple platforms"
        }

        for manifest in nestedSwiftPackageManifests(at: root) {
            languages["Swift", default: 0] += 2
            dependencies.formUnion(swiftPackageDependencies(at: manifest))
        }

        let sourceSignals = scanSourceSignals(at: root)
        for (language, score) in sourceSignals.languages {
            languages[language, default: 0] += score
        }
        frameworks.formUnion(sourceSignals.frameworks)

        let readme = readReadme(at: root)
        let description = readme.description
        let keywords = readme.keywords
        let inferredType = inferProjectType(root: root, frameworks: frameworks, dependencies: dependencies)

        if frameworks.contains("SwiftUI") || dependencies.contains("SwiftUI") {
            platform = platform ?? "Apple platforms"
        }

        return ProjectProfile(
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

    /// 读取用户项目中的文本文件，允许 Foundation 根据 BOM 或内容检测编码。
    private func readTextFile(_ url: URL) -> String? {
        var detectedEncoding = String.Encoding.utf8
        return try? String(contentsOf: url, usedEncoding: &detectedEncoding)
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

    /// 检查根目录是否包含 Xcode 工程或 workspace。
    private func containsXcodeProject(at root: URL) -> Bool {
        guard let items = try? fileManager.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else {
            return false
        }
        return items.contains { item in
            item.pathExtension == "xcodeproj" || item.pathExtension == "xcworkspace"
        }
    }

    /// 查找子目录中的 Swift Package 清单文件。
    private func nestedSwiftPackageManifests(at root: URL) -> [URL] {
        let rootManifest = root.appendingPathComponent("Package.swift").standardizedFileURL
        return projectFiles(at: root, matchingExtensions: ["swift"])
            .filter { $0.lastPathComponent == "Package.swift" && $0.standardizedFileURL != rootManifest }
    }

    /// 从 `Package.swift` 提取 Swift 包依赖仓库名称。
    private func swiftPackageDependencies(at url: URL) -> [String] {
        guard let text = readTextFile(url) else { return [] }
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
        guard let text = readTextFile(url) else { return [] }
        return regexMatches(pattern: #"pod\s+['"]([^'"]+)['"]"#, text: text)
    }

    /// 从 `Podfile` 提取平台声明。
    private func podPlatform(at url: URL) -> String? {
        guard let text = readTextFile(url),
              let value = regexMatches(pattern: #"platform\s+:(\w+),\s*['"]([^'"]+)['"]"#, text: text).first else {
            return nil
        }
        return value
    }

    /// 从 `go.mod` 提取直接 Go 模块依赖。
    private func goDependencies(at url: URL) -> [String] {
        guard let text = readTextFile(url) else { return [] }
        var dependencies: [String] = []
        var inRequireBlock = false

        for line in text.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("//") { continue }

            if inRequireBlock {
                if trimmed == ")" {
                    inRequireBlock = false
                    continue
                }
                if let dependency = goDependencyName(from: String(trimmed)) {
                    dependencies.append(dependency)
                }
                continue
            }

            let requireDeclaration = trimmed.split(
                maxSplits: 1,
                whereSeparator: \.isWhitespace
            )
            guard requireDeclaration.first == "require", requireDeclaration.count == 2 else { continue }
            let declaration = String(requireDeclaration[1]).trimmingCharacters(in: .whitespaces)
            if declaration == "(" {
                inRequireBlock = true
            } else if let dependency = goDependencyName(from: declaration) {
                dependencies.append(dependency)
            }
        }

        return dependencies
    }

    private func goDependencyName(from declaration: String) -> String? {
        let dependencyLine = declaration.split(separator: "//", maxSplits: 1).first ?? ""
        return dependencyLine.split(whereSeparator: \.isWhitespace).first.map(String.init)
    }

    /// 从 TOML 文件的 `[dependencies]` 段提取依赖名称。
    private func tomlDependencyNames(at url: URL) -> [String] {
        guard let text = readTextFile(url) else { return [] }
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
        if let text = readTextFile(requirements) {
            result += text.split(separator: "\n").compactMap { line in
                let clean = line
                    .split(separator: "#", omittingEmptySubsequences: false)
                    .first?
                    .trimmingCharacters(in: .whitespaces) ?? ""
                guard !clean.isEmpty else { return nil }
                return clean.split(whereSeparator: { "=<>~ ".contains($0) }).first.map(String.init)
            }
        }
        result += pyprojectDependencies(at: root.appendingPathComponent("pyproject.toml"))
        return result
    }

    private func pyprojectDependencies(at url: URL) -> [String] {
        guard let text = readTextFile(url) else { return [] }
        var dependencies: [String] = []
        var section = ""
        var collectingArray: String?
        var arrayText = ""

        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = stripTOMLComment(String(rawLine)).trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }

            if line.hasPrefix("[") && line.hasSuffix("]") {
                section = String(line.dropFirst().dropLast())
                collectingArray = nil
                arrayText = ""
                continue
            }

            if collectingArray != nil {
                arrayText += "\n" + line
                if line.contains("]") {
                    dependencies += pythonDependencyNames(fromTOMLArray: arrayText)
                    collectingArray = nil
                    arrayText = ""
                }
                continue
            }

            if section == "project" {
                guard let (key, value) = tomlKeyValue(from: line), key == "dependencies" else { continue }
                if value.contains("]") {
                    dependencies += pythonDependencyNames(fromTOMLArray: value)
                } else {
                    collectingArray = "dependencies"
                    arrayText = value
                }
                continue
            }

            if section.hasPrefix("project.optional-dependencies"),
               let value = tomlValue(from: line) {
                if value.contains("]") {
                    dependencies += pythonDependencyNames(fromTOMLArray: value)
                } else {
                    collectingArray = "optional-dependencies"
                    arrayText = value
                }
                continue
            }

            if isPoetryDependencySection(section),
               let key = line.split(separator: "=", maxSplits: 1).first?.trimmingCharacters(in: .whitespaces),
               key != "python",
               !key.isEmpty {
                dependencies.append(key.trimmingCharacters(in: CharacterSet(charactersIn: "\"'")))
            }
        }

        return dependencies
    }

    private func tomlKeyValue(from line: String) -> (key: String, value: String)? {
        guard let equalsIndex = line.firstIndex(of: "=") else { return nil }
        let key = String(line[..<equalsIndex]).trimmingCharacters(in: .whitespaces)
        let value = String(line[line.index(after: equalsIndex)...]).trimmingCharacters(in: .whitespaces)
        return (key, value)
    }

    private func tomlValue(from line: String) -> String? {
        tomlKeyValue(from: line)?.value
    }

    private func pythonDependencyNames(fromTOMLArray text: String) -> [String] {
        regexMatches(pattern: #"["']([^"']+)["']"#, text: text)
            .compactMap(pythonDependencyName(from:))
    }

    private func pythonDependencyName(from requirement: String) -> String? {
        let withoutEnvironmentMarker = requirement
            .split(separator: ";", maxSplits: 1)
            .first?
            .trimmingCharacters(in: .whitespaces) ?? ""
        return withoutEnvironmentMarker
            .split(whereSeparator: { "=<>~! ".contains($0) })
            .first
            .map(String.init)
    }

    private func stripTOMLComment(_ line: String) -> String {
        var result = ""
        var inSingleQuote = false
        var inDoubleQuote = false

        for character in line {
            if character == "'", !inDoubleQuote {
                inSingleQuote.toggle()
            } else if character == "\"", !inSingleQuote {
                inDoubleQuote.toggle()
            } else if character == "#", !inSingleQuote, !inDoubleQuote {
                break
            }
            result.append(character)
        }

        return result
    }

    private func isPoetryDependencySection(_ section: String) -> Bool {
        section == "tool.poetry.dependencies" ||
            (section.hasPrefix("tool.poetry.group.") && section.hasSuffix(".dependencies"))
    }

    /// 递归扫描源码文件，补充语言和框架信号。
    private func scanSourceSignals(at root: URL) -> (languages: [String: Int], frameworks: Set<String>) {
        var languages: [String: Int] = [:]
        var frameworks = Set<String>()
        for file in projectFiles(at: root, matchingExtensions: Set(Self.sourceLanguageByExtension.keys)) {
            let ext = file.pathExtension.lowercased()
            if let language = Self.sourceLanguageByExtension[ext] {
                languages[language, default: 0] += 1
            }
            if ext == "swift", file.lastPathComponent != "Package.swift" {
                frameworks.formUnion(swiftFrameworkImports(at: file))
            }
        }
        return (languages, frameworks)
    }

    /// 返回项目内符合扩展名条件的文件，跳过依赖、构建缓存和隐藏目录。
    private func projectFiles(at root: URL, matchingExtensions extensions: Set<String>) -> [URL] {
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var files: [URL] = []
        for case let url as URL in enumerator {
            let name = url.lastPathComponent
            if Self.ignoredDirectoryNames.contains(name), isDirectory(url) {
                enumerator.skipDescendants()
                continue
            }
            guard extensions.contains(url.pathExtension.lowercased()) else {
                continue
            }
            files.append(url)
        }
        return files
    }

    /// 判断 URL 是否指向目录。
    private func isDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    /// 从 Swift 源码 import 声明中提取常见框架。
    private func swiftFrameworkImports(at url: URL) -> [String] {
        guard let text = readTextFile(url) else { return [] }
        let imports = regexMatches(pattern: #"(?m)^\s*import\s+([A-Za-z_][A-Za-z0-9_]*)"#, text: text)
        return imports.filter { Self.swiftFrameworkNames.contains($0) }
    }

    /// 从 README 内容中提取简短描述和高频关键词。
    private func readReadme(at root: URL) -> (description: String, keywords: [String]) {
        let candidates = ["README.md", "README_zh.md", "Readme.md", "readme.md"]
        guard let url = candidates.map({ root.appendingPathComponent($0) }).first(where: { fileManager.fileExists(atPath: $0.path) }),
              let text = readTextFile(url) else {
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
    private func inferProjectType(root: URL, frameworks: Set<String>, dependencies: Set<String>) -> ProjectType {
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

    /// 源码扩展名到语言名称的映射。
    private static let sourceLanguageByExtension: [String: String] = [
        "swift": "Swift",
        "m": "Objective-C",
        "mm": "Objective-C",
        "h": "Objective-C",
        "ts": "TypeScript",
        "tsx": "TypeScript",
        "js": "JavaScript",
        "jsx": "JavaScript",
        "py": "Python",
        "go": "Go",
        "rs": "Rust",
        "kt": "Kotlin",
        "kts": "Kotlin",
        "java": "Java"
    ]

    /// 递归扫描时忽略的目录。
    private static let ignoredDirectoryNames: Set<String> = [
        ".build",
        ".git",
        ".swiftpm",
        "DerivedData",
        "node_modules",
        "Pods",
        "Carthage",
        ".bundle"
    ]

    /// 用作项目画像框架信号的 Swift 模块。
    private static let swiftFrameworkNames: Set<String> = [
        "SwiftUI",
        "AppKit",
        "UIKit",
        "Combine",
        "Foundation",
        "SwiftData",
        "CoreData",
        "Network",
        "WebKit",
        "XCTest",
        "Vapor"
    ]
}
