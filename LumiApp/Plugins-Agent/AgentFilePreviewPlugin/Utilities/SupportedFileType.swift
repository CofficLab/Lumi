import Foundation

/// 支持预览的文件类型
enum SupportedFileType {
    /// Markdown 文件
    private static let markdownExtensions = ["md", "markdown"]

    /// 纯文本文件
    private static let textExtensions = [
        // 通用文本
        "txt", "text",
        // Git 配置文件
        "gitignore", "gitattributes", "gitmodules",
    ]

    /// Git 配置文件的完整文件名（无扩展名）
    private static let gitConfigFileNames = [".gitignore", ".gitattributes", ".gitmodules"]

    /// 编程语言源代码文件
    private static let codeExtensions = [
        // Swift
        "swift",
        // Objective-C
        "m", "mm", "h",
        // C/C++
        "c", "cpp", "cc", "cxx", "hpp", "hxx",
        // Java
        "java",
        // Kotlin
        "kt", "kts",
        // Python
        "py", "pyw",
        // JavaScript/TypeScript
        "js", "jsx", "ts", "tsx", "mjs", "cjs",
        // Web
        "html", "htm", "css", "scss", "sass", "less", "vue", "svelte",
        // Ruby
        "rb", "erb",
        // PHP
        "php",
        // Go
        "go",
        // Rust
        "rs",
        // C#
        "cs",
        // F#
        "fs", "fsx",
        // Scala
        "scala",
        // Shell
        "sh", "bash", "zsh", "fish",
        // PowerShell
        "ps1", "psm1", "psd1",
        // Lua
        "lua",
        // Perl
        "pl", "pm",
        // R
        "r", "R",
        // Julia
        "jl",
        // Haskell
        "hs", "lhs",
        // Erlang
        "erl", "hrl",
        // Elixir
        "ex", "exs",
        // Clojure
        "clj", "cljc", "cljs",
        // SQL
        "sql",
        // GraphQL
        "graphql", "gql",
        // Protocol Buffers
        "proto",
        // Makefile
        "mk", "makefile", "make",
        // Dockerfile
        "dockerfile",
        // YAML/TOML/JSON
        "yaml", "yml", "toml", "json",
        // XML
        "xml",
        // Configuration
        "ini", "cfg", "conf", "config",
        // Log
        "log",
    ]

    /// 判断文件扩展名是否可预览
    /// - Parameter extension: 文件扩展名（不含点）
    /// - Returns: 是否可预览
    static func isPreviewable(_ extension: String) -> Bool {
        let normalizedExtension = `extension`.lowercased()
        return markdownExtensions.contains(normalizedExtension)
            || textExtensions.contains(normalizedExtension)
            || codeExtensions.contains(normalizedExtension)
    }

    /// 判断文件是否可预览（通过文件名）
    /// - Parameter fileName: 文件名（如 .gitignore）
    /// - Returns: 是否可预览
    static func isPreviewable(fileName: String) -> Bool {
        return gitConfigFileNames.contains(fileName)
    }

    /// 获取文件类型描述
    /// - Parameter fileName: 文件名或扩展名
    /// - Returns: 文件类型描述（如 "Markdown", "文本", "代码" 等）
    static func fileTypeDescription(for fileNameOrExtension: String, fullFileName: String? = nil) -> String {
        // 先检查是否是 Git 配置文件
        if let fullFileName = fullFileName, gitConfigFileNames.contains(fullFileName) {
            return "Git 配置"
        }

        let normalized = fileNameOrExtension.lowercased()

        if markdownExtensions.contains(normalized) {
            return "Markdown"
        }

        if textExtensions.contains(normalized) {
            // 检查是否是 Git 配置文件（通过扩展名判断）
            if ["gitignore", "gitattributes", "gitmodules"].contains(normalized) {
                return "Git 配置"
            }
            return "文本"
        }

        if codeExtensions.contains(normalized) {
            return "代码"
        }

        return "未知"
    }

    /// 判断文件是否为代码文件
    /// - Parameter extension: 文件扩展名（不含点）
    /// - Returns: 是否为代码文件
    static func isCodeFile(_ extension: String) -> Bool {
        let normalizedExtension = `extension`.lowercased()
        return codeExtensions.contains(normalizedExtension)
    }

    /// 判断文件是否为 Markdown 文件
    /// - Parameter extension: 文件扩展名（不含点）
    /// - Returns: 是否为 Markdown 文件
    static func isMarkdownFile(_ extension: String) -> Bool {
        let normalizedExtension = `extension`.lowercased()
        return markdownExtensions.contains(normalizedExtension)
    }

    /// 判断文件是否为纯文本文件
    /// - Parameter extension: 文件扩展名（不含点）
    /// - Returns: 是否为纯文本文件
    static func isTextFile(_ extension: String) -> Bool {
        let normalizedExtension = `extension`.lowercased()
        return textExtensions.contains(normalizedExtension)
    }
}
