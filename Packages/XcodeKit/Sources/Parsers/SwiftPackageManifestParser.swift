import Foundation

/// 轻量级 `Package.swift` 解析器，用于发现本地包依赖与 target 源码根目录。
public enum SwiftPackageManifestParser {

    struct TargetSourceRoot: Equatable, Sendable {
        let relativePath: String
        let excludedRelativePaths: Set<String>
    }

    static func localPackageDependencyPaths(packageRoot: URL) -> [URL] {
        guard let text = readManifest(at: packageRoot) else { return [] }
        return regexMatches(pattern: localPackagePathPattern, in: text).compactMap { match in
            guard let range = Range(match.range(at: 1), in: text) else { return nil }
            let relativePath = String(text[range])
            return packageRoot.appendingPathComponent(relativePath).standardizedFileURL
        }
    }

    static func regularTargetSourceRoots(packageRoot: URL) -> [TargetSourceRoot] {
        guard let text = readManifest(at: packageRoot) else { return [] }
        var roots: [TargetSourceRoot] = []

        for match in regexMatches(pattern: targetDeclarationPattern, in: text) {
            guard let kindRange = Range(match.range(at: 1), in: text),
                  let nameRange = Range(match.range(at: 2), in: text),
                  String(text[kindRange]) == "target" else {
                continue
            }

            let targetName = String(text[nameRange])
            let block = targetBlock(in: text, startingAt: match.range.location + match.range.length)
            let explicitPath = captureFirstGroup(in: block, pattern: targetPathPattern)
            let excluded = captureQuotedStrings(in: block, pattern: targetExcludePattern)

            if let explicitPath {
                roots.append(TargetSourceRoot(relativePath: explicitPath, excludedRelativePaths: excluded))
                continue
            }

            let defaultNamedPath = "Sources/\(targetName)"
            if FileManager.default.fileExists(atPath: packageRoot.appendingPathComponent(defaultNamedPath).path) {
                roots.append(TargetSourceRoot(relativePath: defaultNamedPath, excludedRelativePaths: excluded))
            } else if FileManager.default.fileExists(atPath: packageRoot.appendingPathComponent("Sources").path) {
                roots.append(TargetSourceRoot(relativePath: "Sources", excludedRelativePaths: excluded))
            }
        }

        return deduplicate(roots)
    }

    public static func executableTargetNames(packageRoot: URL) -> [String] {
        if let manifestTargets = executableTargetsFromManifest(packageRoot: packageRoot), !manifestTargets.isEmpty {
            return manifestTargets
        }
        return executableTargetsFromDescribe(packageRoot: packageRoot)
    }

    public static func targetName(forFile fileURL: URL, packageRoot: URL) -> String? {
        let filePath = fileURL.standardizedFileURL.path
        let executableTargets = executableTargetNames(packageRoot: packageRoot)
        guard !executableTargets.isEmpty else { return nil }

        for target in executableTargets {
            let defaultPath = packageRoot.appendingPathComponent("Sources/\(target)").path
            if filePath.hasPrefix(defaultPath + "/") || filePath == defaultPath {
                return target
            }
        }

        for root in regularTargetSourceRoots(packageRoot: packageRoot) {
            let sourcePath = packageRoot.appendingPathComponent(root.relativePath).path
            guard filePath.hasPrefix(sourcePath + "/") || filePath == sourcePath else { continue }
            let folderName = URL(fileURLWithPath: root.relativePath).lastPathComponent
            if executableTargets.contains(folderName) {
                return folderName
            }
        }
        return nil
    }

    public static func findPackageDirectory(for fileOrDirectoryURL: URL) -> URL? {
        let fileManager = FileManager.default
        var currentDir = fileOrDirectoryURL
        if !currentDir.hasDirectoryPath {
            currentDir = currentDir.deletingLastPathComponent()
        }

        while currentDir.path != "/" && !currentDir.path.isEmpty {
            let packageSwiftURL = currentDir.appendingPathComponent("Package.swift")
            if fileManager.fileExists(atPath: packageSwiftURL.path) {
                return currentDir
            }
            let parentDir = currentDir.deletingLastPathComponent()
            if parentDir.path == currentDir.path { break }
            currentDir = parentDir
        }
        return nil
    }

    static func localTransitivePackageRoots(from start: URL) -> Set<URL> {
        var visited = Set<String>()
        var queue = [start.standardizedFileURL]
        var result = Set<URL>()

        while let current = queue.first {
            queue.removeFirst()
            let currentPath = current.path
            guard visited.insert(currentPath).inserted else { continue }
            guard FileManager.default.fileExists(atPath: current.appendingPathComponent("Package.swift").path) else {
                continue
            }

            result.insert(current)
            for dependency in localPackageDependencyPaths(packageRoot: current) {
                if !visited.contains(dependency.path) {
                    queue.append(dependency)
                }
            }
        }

        return result
    }

    // MARK: - Private

    private static let localPackagePathPattern = #"\.package\(\s*path:\s*"([^"]+)""#
    private static let targetDeclarationPattern = #"\.(target|testTarget|executableTarget)\(\s*name:\s*"([^"]+)""#
    private static let executableTargetDeclarationPattern = #"\.executableTarget\(\s*name:\s*"([^"]+)""#
    private static let targetPathPattern = #"path:\s*"([^"]+)""#
    private static let targetExcludePattern = #"exclude:\s*\[([^\]]*)\]"#

    private static func readManifest(at packageRoot: URL) -> String? {
        let manifestURL = packageRoot.appendingPathComponent("Package.swift")
        guard FileManager.default.fileExists(atPath: manifestURL.path) else { return nil }
        return try? String(contentsOf: manifestURL, encoding: .utf8)
    }

    private static func regexMatches(pattern: String, in text: String) -> [NSTextCheckingResult] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return []
        }
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
    }

    private static func targetBlock(in text: String, startingAt offset: Int) -> String {
        let startIndex = text.index(text.startIndex, offsetBy: min(offset, text.count))
        let suffix = String(text[startIndex...])
        guard let nextDeclaration = suffix.range(
            of: #"\.(?:target|testTarget)\("#,
            options: .regularExpression,
            range: suffix.index(suffix.startIndex, offsetBy: min(1, suffix.count))..<suffix.endIndex
        ) else {
            return suffix
        }
        return String(suffix[..<nextDeclaration.lowerBound])
    }

    private static func captureFirstGroup(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[range])
    }

    private static func captureQuotedStrings(in text: String, pattern: String) -> Set<String> {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else {
            return []
        }
        let excludeBlock = String(text[range])
        let quotedPattern = #""([^"]+)""#
        guard let quotedRegex = try? NSRegularExpression(pattern: quotedPattern) else { return [] }
        let values = quotedRegex.matches(in: excludeBlock, range: NSRange(excludeBlock.startIndex..., in: excludeBlock))
            .compactMap { item -> String? in
                guard let valueRange = Range(item.range(at: 1), in: excludeBlock) else { return nil }
                return String(excludeBlock[valueRange])
            }
        return Set(values)
    }

    private static func deduplicate(_ roots: [TargetSourceRoot]) -> [TargetSourceRoot] {
        var seen = Set<String>()
        return roots.filter { root in
            let key = "\(root.relativePath)|\(root.excludedRelativePaths.sorted().joined(separator: ","))"
            return seen.insert(key).inserted
        }
    }

    private static func executableTargetsFromManifest(packageRoot: URL) -> [String]? {
        guard let text = readManifest(at: packageRoot) else { return nil }
        var names: [String] = []
        for match in regexMatches(pattern: executableTargetDeclarationPattern, in: text) {
            guard let nameRange = Range(match.range(at: 1), in: text) else { continue }
            names.append(String(text[nameRange]))
        }
        return names.isEmpty ? nil : names
    }

    private static func executableTargetsFromDescribe(packageRoot: URL) -> [String] {
        guard let swiftPath = SPMUserBuildRunner.locateSwiftExecutable() else { return [] }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [swiftPath, "package", "describe", "--type", "json", "--package-path", packageRoot.path]
        process.currentDirectoryURL = packageRoot
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return [] }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let targets = json["targets"] as? [[String: Any]] else {
                return []
            }
            return targets.compactMap { target in
                guard let type = target["type"] as? String, type == "executable",
                      let name = target["name"] as? String else {
                    return nil
                }
                return name
            }
        } catch {
            return []
        }
    }
}
