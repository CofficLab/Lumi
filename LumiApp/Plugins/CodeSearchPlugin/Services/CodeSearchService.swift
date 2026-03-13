import Foundation
import MagicKit
import OSLog

/// 代码搜索服务
///
/// 封装代码搜索和文件查找功能。
final class CodeSearchService: @unchecked Sendable, SuperLog {
    nonisolated static let emoji = "🔍"
    static let shared = CodeSearchService()

    private init() {}

    // MARK: - Code Search

    func search(
        pattern: String,
        path: String?,
        filePattern: String?,
        excludePattern: String?,
        ignoreCase: Bool,
        contextLines: Int,
        maxResults: Int
    ) async throws -> [SearchResult] {
        let searchDir = path.map { URL(fileURLWithPath: $0) } ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

        // 构建 grep 命令
        var args: [String] = ["-n", "-H", "--color=never"]

        // 忽略大小写
        if ignoreCase {
            args.append("-i")
        }

        // 上下文行数
        if contextLines > 0 {
            args.append("-C")
            args.append("\(contextLines)")
        }

        // 文件模式
        if let filePattern = filePattern, !filePattern.isEmpty {
            args.append("--include=\(filePattern)")
        }

        // 排除模式
        if let excludePattern = excludePattern, !excludePattern.isEmpty {
            args.append("--exclude=\(excludePattern)")
        }

        // 排除常见目录
        args.append("--exclude-dir=.git")
        args.append("--exclude-dir=node_modules")
        args.append("--exclude-dir=.build")
        args.append("--exclude-dir=DerivedData")
        args.append("--exclude-dir=vendor")
        args.append("--exclude-dir=Pods")

        args.append(pattern)

        let output = try await runGrep(args: args, in: searchDir)

        return parseGrepOutput(output, searchDir: searchDir, maxResults: maxResults)
    }

    // MARK: - Find Files

    func findFiles(pattern: String, path: String?, exclude: String?, maxResults: Int) async throws -> [String] {
        let searchDir = path.map { URL(fileURLWithPath: $0) } ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

        // 使用 find 命令进行 glob 匹配
        var args: [String] = [
            ".",
            "-name", pattern,
            "-type", "f"
        ]

        // 排除
        if let exclude = exclude, !exclude.isEmpty {
            args.append("-not")
            args.append("-path")
            args.append(exclude)
        }

        // 排除常见目录
        args.append("-not")
        args.append("-path")
        args.append("*/.git/*")
        args.append("-not")
        args.append("-path")
        args.append("*/node_modules/*")
        args.append("-not")
        args.append("-path")
        args.append("*/.build/*")
        args.append("-not")
        args.append("-path")
        args.append("*/DerivedData/*")
        args.append("-not")
        args.append("-path")
        args.append("*/vendor/*")
        args.append("-not")
        args.append("-path")
        args.append("*/Pods/*")

        let output = try await runFind(args: args, in: searchDir)

        var files = output
            .components(separatedBy: "\n")
            .filter { !$0.isEmpty }
            .map { $0.replacingOccurrences(of: "./", with: "") }
            .prefix(maxResults)

        return Array(files)
    }

    // MARK: - Helper

    private func runGrep(args: [String], in directory: URL) async throws -> String {
        let process = Process()
        let pipe = Pipe()

        // 优先使用 rg (ripgrep)，如果不存在则使用 grep
        let grepPath = "/usr/bin/grep"

        process.executableURL = URL(fileURLWithPath: grepPath)
        process.arguments = args
        process.standardOutput = pipe
        process.standardError = pipe
        process.currentDirectoryURL = directory

        // 设置环境变量
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        env["LANG"] = "en_US.UTF-8"
        process.environment = env

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        // grep 返回 1 表示没有找到匹配，这是正常的
        if process.terminationStatus != 0 && process.terminationStatus != 1 {
            throw NSError(
                domain: "CodeSearchService",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: output.trimmingCharacters(in: .whitespacesAndNewlines)]
            )
        }

        return output
    }

    private func runFind(args: [String], in directory: URL) async throws -> String {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/find")
        process.arguments = args
        process.standardOutput = pipe
        process.standardError = pipe
        process.currentDirectoryURL = directory

        // 设置环境变量
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        env["LANG"] = "en_US.UTF-8"
        process.environment = env

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        if process.terminationStatus != 0 {
            throw NSError(
                domain: "CodeSearchService",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: output.trimmingCharacters(in: .whitespacesAndNewlines)]
            )
        }

        return output
    }

    // MARK: - Parse Output

    private func parseGrepOutput(_ output: String, searchDir: URL, maxResults: Int) -> [SearchResult] {
        var results: [SearchResult] = []
        var currentResult: SearchResult?
        var currentMatches: [Match] = []
        var currentFile: String?

        let lines = output.components(separatedBy: "\n")
        var i = 0

        while i < lines.count && results.count < maxResults {
            let line = lines[i]

            // 检测分隔线 (-- 开头的是 grep -C 输出的分隔符)
            if line.hasPrefix("--") {
                i += 1
                continue
            }

            // 解析匹配行：格式为 "file:lineNumber:content"
            let parts = line.split(separator: ":", maxSplits: 2)
            if parts.count >= 3 {
                let file = String(parts[0])
                let lineNumber = Int(parts[1]) ?? 0
                let content = String(parts[2])

                // 新文件
                if file != currentFile {
                    // 保存之前的结果
                    if let currentResult = currentResult, !currentMatches.isEmpty {
                        var newResult = currentResult
                        newResult.matches = Array(currentMatches.prefix(10)) // 限制每个文件的匹配数
                        results.append(newResult)
                    }

                    currentFile = file
                    currentMatches = []

                    let relativePath = file.replacingOccurrences(of: searchDir.path + "/", with: "")
                    let language = guessLanguage(for: relativePath)

                    currentResult = SearchResult(
                        filePath: file,
                        relativePath: relativePath,
                        matches: [],
                        language: language
                    )
                }

                // 添加匹配
                if var result = currentResult {
                    let match = Match(
                        lineNumber: lineNumber,
                        line: content,
                        contextBefore: nil,
                        contextAfter: nil
                    )
                    currentMatches.append(match)
                }
            } else if !line.isEmpty && currentFile != nil {
                // 上下文行（没有行号）
                if currentMatches.isEmpty {
                    // 这是分隔线后的上下文
                } else if let lastMatch = currentMatches.popLast() {
                    // 简单处理：添加到 contextAfter
                    var updatedMatch = lastMatch
                    if var contextAfter = updatedMatch.contextAfter {
                        contextAfter.append(line)
                        updatedMatch.contextAfter = contextAfter
                    } else {
                        updatedMatch.contextAfter = [line]
                    }
                    currentMatches.append(updatedMatch)
                }
            }

            i += 1
        }

        // 保存最后一个结果
        if var currentResult = currentResult, !currentMatches.isEmpty {
            currentResult.matches = Array(currentMatches.prefix(10))
            results.append(currentResult)
        }

        return results
    }

    private func guessLanguage(for filePath: String) -> String? {
        let ext = (filePath as NSString).pathExtension
        switch ext {
        case "swift": return "swift"
        case "js", "jsx": return "javascript"
        case "ts", "tsx": return "typescript"
        case "py": return "python"
        case "rb": return "ruby"
        case "java": return "java"
        case "kt": return "kotlin"
        case "go": return "go"
        case "rs": return "rust"
        case "c", "h": return "c"
        case "cpp", "hpp", "cc": return "cpp"
        case "cs": return "csharp"
        case "php": return "php"
        case "vue": return "vue"
        case "svelte": return "svelte"
        case "html": return "html"
        case "css", "scss", "less": return "css"
        case "json": return "json"
        case "md": return "markdown"
        case "yaml", "yml": return "yaml"
        case "sh", "zsh", "bash": return "bash"
        default: return nil
        }
    }
}
