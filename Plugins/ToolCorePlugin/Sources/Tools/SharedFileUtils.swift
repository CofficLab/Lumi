import Foundation

// MARK: - File Enumeration Helpers

/// 需要跳过的目录（版本控制、构建产物、依赖等）
let SKIP_DIRECTORIES: Set<String> = [
    ".git", ".svn", ".hg", ".bzr", ".jj", ".sl",
    "node_modules", ".build", "DerivedData",
    "build", "dist", ".next", ".nuxt", "target",
    "__pycache__", ".tox", ".mypy_cache",
    ".gradle", ".idea", ".vscode",
]

/// 文件扩展名到语言类型的映射
let EXTENSION_TO_TYPE: [String: String] = [
    "swift": "swift", "m": "objc", "mm": "objc",
    "js": "js", "jsx": "js", "mjs": "js", "cjs": "js",
    "ts": "ts", "tsx": "ts", "mts": "ts",
    "py": "python", "pyw": "python",
    "rs": "rust",
    "go": "go",
    "java": "java", "kt": "kotlin", "kts": "kotlin",
    "c": "c", "h": "c", "cpp": "cpp", "cc": "cpp", "cxx": "cpp", "hpp": "cpp",
    "rb": "ruby",
    "php": "php",
    "cs": "csharp",
    "scala": "scala",
    "sh": "shell", "bash": "shell", "zsh": "shell",
    "html": "html", "htm": "html",
    "css": "css", "scss": "css", "sass": "css", "less": "css",
    "json": "json", "yaml": "yaml", "yml": "yaml", "toml": "toml",
    "xml": "xml", "svg": "xml",
    "md": "markdown", "mdx": "markdown",
    "sql": "sql",
    "lua": "lua",
    "dart": "dart",
    "ex": "elixir", "exs": "elixir",
    "erl": "erlang",
    "hs": "haskell",
    "clj": "clojure",
    "r": "r",
    "vue": "vue",
    "svelte": "svelte",
]

/// 语言类型到扩展名的反向映射
let TYPE_TO_EXTENSIONS: [String: Set<String>] = {
    var map: [String: Set<String>] = [:]
    for (ext, type) in EXTENSION_TO_TYPE {
        map[type, default: []].insert(ext)
    }
    // 补充别名
    map["typescript"] = map["ts"]
    map["javascript"] = map["js"]
    map["objective-c"] = map["objc"]
    map["c++"] = map["cpp"]
    return map
}()

/// 语言类型到文件名的映射（用于没有扩展名的文件）
let TYPE_TO_FILENAMES: [String: Set<String>] = [
    "shell": ["Makefile", "Dockerfile", "Vagrantfile", "Gemfile", "Rakefile", "Podfile", "Fastfile"],
    "js": ["package.json"],
    "python": ["requirements.txt", "setup.py", "pyproject.toml"],
    "yaml": [".gitlab-ci.yml", ".travis.yml"],
]

/// 判断文件扩展名是否匹配指定类型
func fileMatchesType(fileName: String, type: String) -> Bool {
    let ext = (fileName as NSString).pathExtension.lowercased()
    if let exts = TYPE_TO_EXTENSIONS[type.lowercased()], exts.contains(ext) {
        return true
    }
    if let names = TYPE_TO_FILENAMES[type.lowercased()], names.contains(fileName) {
        return true
    }
    return false
}

/// 枚举目录中所有文件，返回 (绝对路径, 相对路径) 的列表
/// 自动跳过隐藏文件和 SKIP_DIRECTORIES 中的目录
func enumerateFiles(in directory: String, maxResults: Int? = nil) -> [(absolute: String, relative: String)] {
    let fm = FileManager.default
    var results: [(absolute: String, relative: String)] = []

    // 计算相对路径前缀长度
    let baseLength = directory.hasSuffix("/") ? directory.count : directory.count + 1

    guard let enumerator = fm.enumerator(
        at: URL(fileURLWithPath: directory),
        includingPropertiesForKeys: [.isDirectoryKey],
        options: [.skipsHiddenFiles]
    ) else {
        return []
    }

    for case let url as URL in enumerator {
        if let max = maxResults, results.count >= max { break }

        let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false

        if isDir {
            let name = url.lastPathComponent
            if SKIP_DIRECTORIES.contains(name) {
                enumerator.skipDescendants()
            }
            continue
        }

        let absolutePath = url.path
        let relativePath = String(absolutePath.dropFirst(baseLength))
        results.append((absolutePath, relativePath))
    }

    return results
}

// MARK: - Glob Pattern Matching

/// 展开花括号: *.{ts,tsx} → [*.ts, *.tsx]
func expandBraces(_ pattern: String) -> [String] {
    guard let openIdx = pattern.firstIndex(of: "{"),
          let closeIdx = pattern.lastIndex(of: "}"),
          openIdx < closeIdx else {
        return [pattern]
    }

    let prefix = String(pattern[pattern.startIndex..<openIdx])
    let suffix = String(pattern[pattern.index(after: closeIdx)...])
    let inner = pattern[pattern.index(after: openIdx)..<closeIdx]

    let alternatives = inner.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
    if alternatives.isEmpty { return [pattern] }

    var results: [String] = []
    for alt in alternatives {
        let expanded = expandBraces("\(prefix)\(alt)\(suffix)")
        results.append(contentsOf: expanded)
    }
    return results
}

/// 编译单个 glob 模式为正则表达式
///
/// 支持：
/// - `*` 匹配单个路径组件内任意字符
/// - `**` 跨目录匹配
/// - `?` 匹配单个字符
/// - `[...]` 字符类
private func compileSingleGlobPattern(_ pattern: String) -> NSRegularExpression? {
    var regex = ""
    var i = pattern.startIndex

    while i < pattern.endIndex {
        let c = pattern[i]
        let nextI = pattern.index(after: i)

        if c == "*" {
            if nextI < pattern.endIndex && pattern[nextI] == "*" {
                // ** — 跨目录匹配
                regex += ".*"
                i = pattern.index(after: nextI)
                // 跳过后面的 /
                if i < pattern.endIndex && pattern[i] == "/" {
                    regex += "/?"
                    i = pattern.index(after: i)
                }
            } else {
                // * — 单个路径组件内匹配
                regex += "[^/]*"
                i = nextI
            }
        } else if c == "?" {
            regex += "[^/]"
            i = nextI
        } else if c == "[" {
            // 字符类 [...]
            var end = nextI
            while end < pattern.endIndex && pattern[end] != "]" {
                end = pattern.index(after: end)
            }
            if end < pattern.endIndex {
                let bracket = pattern[nextI..<end]
                regex += "[\(bracket)]"
                i = pattern.index(after: end)
            } else {
                regex += "\\["
                i = nextI
            }
        } else {
            // 转义正则特殊字符
            if "\\^$.|+(){}!".contains(c) {
                regex += "\\\(c)"
            } else {
                regex += String(c)
            }
            i = nextI
        }
    }

    return try? NSRegularExpression(pattern: "^\(regex)$", options: [])
}

/// 判断路径是否匹配 glob 模式
///
/// 支持：
/// - `*` 匹配单个路径组件内任意字符
/// - `**` 跨目录匹配
/// - `?` 匹配单个字符
/// - `[...]` 字符类
/// - `{a,b,c}` 花括号展开
func matchesGlobPattern(_ pattern: String, path: String) -> Bool {
    let expanded = expandBraces(pattern)
    for p in expanded {
        if let regex = compileSingleGlobPattern(p) {
            let range = NSRange(path.startIndex..., in: path)
            if regex.firstMatch(in: path, options: [], range: range) != nil {
                return true
            }
        }
    }
    return false
}
