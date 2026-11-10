import Foundation
import KitAgentTool

/// 基于语义的 shell 命令风险评估。
///
/// 判定模型:
/// - 目标不是“精确分类”，而是决定“是否需要用户确认”，因此宁可多问、不可漏报。
/// - 命中高置信危险特征 → `.high`。
/// - 无法可靠解析（引号/括号不闭合、超长、嵌套过深）→ `.high`。
/// - 只有“只读白名单命令 + 无敏感路径 + 无危险重定向”才返回 `.low`。
/// - 不在白名单内的命令一律 `.high`（fail-safe）；不使用 `.medium`，因为它同样不需要授权。
enum ShellCommandRiskAnalyzer {
    struct Assessment: Equatable {
        let level: CommandRiskLevel
        let reasons: [String]
    }

    /// 超过该长度直接判高风险，避免在异常输入上做无界分析。
    private static let maxInputLength = 100_000
    private static let maxDepth = 6

    static func riskLevel(for command: String) -> CommandRiskLevel {
        assess(command).level
    }

    static func assess(_ command: String) -> Assessment {
        var reasons: [String] = []
        let level = analyze(command, depth: 0, reasons: &reasons)
        return Assessment(level: level, reasons: reasons)
    }

    // MARK: - 递归分析

    private static func analyze(_ command: String, depth: Int, reasons: inout [String]) -> CommandRiskLevel {
        if depth > maxDepth {
            add("嵌套层数过深，无法可靠分析", &reasons)
            return .high
        }
        if command.utf8.count > maxInputLength {
            add("命令长度超限，无法可靠分析", &reasons)
            return .high
        }
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .low }

        let parsed = parse(trimmed)
        if parsed.malformed {
            add("命令含未闭合的引号、括号或命令替换，无法可靠解析", &reasons)
            return .high
        }

        var level: CommandRiskLevel = .low
        for nested in parsed.nested {
            if analyze(nested, depth: depth + 1, reasons: &reasons) == .high {
                level = .high
            }
        }
        for segment in parsed.segments {
            if assessSegment(segment, depth: depth, reasons: &reasons) == .high {
                level = .high
            }
        }
        return level
    }

    private static func assessSegment(_ segment: String, depth: Int, reasons: inout [String]) -> CommandRiskLevel {
        let lowercased = segment.lowercased()

        if lowercased.contains("/dev/tcp/") {
            add("使用 /dev/tcp 网络通道", &reasons)
            return .high
        }
        if let fragment = sensitiveFragments.first(where: { lowercased.contains($0) }) {
            add("访问敏感路径片段 \(fragment)", &reasons)
            return .high
        }
        if hasDangerousRedirection(segment) {
            add("写重定向到非 /dev/null 目标", &reasons)
            return .high
        }

        let tokens = words(in: segment)
        guard let name = commandName(from: tokens) else { return .low }

        if networkCommands.contains(name) {
            add("网络工具 \(name) 可能外发或下载内容", &reasons)
            return .high
        }
        if interpreterCommands.contains(name) {
            add("解释器或间接执行器 \(name)", &reasons)
            // 内层字符串必须递归分析，而不是当成普通参数。
            for literal in quotedLiterals(in: segment) {
                _ = analyze(literal, depth: depth + 1, reasons: &reasons)
            }
            return .high
        }
        if privilegeCommands.contains(name) {
            add("提权或权限变更命令 \(name)", &reasons)
            return .high
        }
        if destructiveCommands.contains(name) {
            add("破坏性或有副作用的命令 \(name)", &reasons)
            return .high
        }
        if readOnlyCommands.contains(name) {
            if readOnlyCommandIsSafe(name: name, tokens: tokens, segment: lowercased) {
                return .low
            }
            add("只读命令 \(name) 带有写入/执行参数", &reasons)
            return .high
        }

        add("未识别的命令 \(name)，按 fail-safe 判定为需要授权", &reasons)
        return .high
    }

    // MARK: - 语义特征

    /// 只读白名单。命令本身不写文件、不执行子进程。
    private static let readOnlyCommands: Set<String> = [
        "ls", "cat", "head", "tail", "grep", "rg", "wc", "stat", "file", "du", "df",
        "pwd", "echo", "printf", "date", "whoami", "id", "uname", "which", "type",
        "diff", "cmp", "sort", "cut", "tr", "basename", "dirname", "realpath",
        "md5", "md5sum", "shasum", "sha256sum", "xxd", "od", "jq",
        "sed", "awk", "find",
    ]

    private static let networkCommands: Set<String> = [
        "curl", "wget", "nc", "ncat", "netcat", "socat", "scp", "sftp",
        "ssh", "telnet", "ftp", "rsync", "aria2c",
    ]

    /// 能执行任意代码或启动子命令的工具，含脚本解释器、shell 内建转发器。
    private static let interpreterCommands: Set<String> = [
        "bash", "sh", "zsh", "fish", "ksh", "dash", "csh", "tcsh",
        "eval", "source", ".", "xargs", "env", "command", "exec", "builtin",
        "nohup", "time", "watch", "screen", "tmux",
        "python", "python3", "perl", "ruby", "node", "nodejs", "php",
        "osascript", "pwsh", "powershell", "lua", "rscript", "swift", "java",
    ]

    private static let privilegeCommands: Set<String> = [
        "sudo", "doas", "su", "chown", "chgrp", "chmod",
    ]

    private static let destructiveCommands: Set<String> = [
        "rm", "rmdir", "mv", "cp", "dd", "truncate", "shred", "mkfs", "diskutil",
        "launchctl", "defaults", "kill", "killall", "pkill", "reboot", "shutdown",
        "halt", "ln", "touch", "tee", "systemsetup", "csrutil", "chflags", "xattr",
        "mount", "umount", "open",
    ]

    /// 出现任一即判高风险：密钥/凭据/浏览器数据等。
    private static let sensitiveFragments: [String] = [
        "../",
        "~/.ssh", "$home/.ssh", ".ssh/", "id_rsa", "id_ed25519",
        "~/.aws", "$home/.aws", ".aws/",
        "~/.gnupg", "$home/.gnupg", ".gnupg/",
        "keychains", "library/safari",
        "library/application support/google/chrome",
        "library/application support/firefox",
        ".env", ".git-credentials", ".netrc", ".npmrc", ".docker/config.json",
        ".bash_history", ".zsh_history",
    ]

    private static func readOnlyCommandIsSafe(name: String, tokens: [String], segment: String) -> Bool {
        switch name {
        case "sed":
            let inPlace = tokens.contains { $0 == "-i" || $0.hasPrefix("-i.") || $0.hasPrefix("--in-place") }
            return !inPlace
        case "find":
            let unsafeFlags = ["-exec", "-execdir", "-delete", "-ok", "-okdir", "-fprint", "-fprint0", "-fls"]
            return !tokens.contains(where: { token in unsafeFlags.contains(where: { token.hasPrefix($0) }) })
        case "awk":
            let compact = segment.replacingOccurrences(of: " ", with: "")
            let execution = ["system(", "|\""]
            let writesFile = compact.contains(">") && (compact.contains("print") || compact.contains("printf"))
            return !execution.contains(where: { compact.contains($0) }) && !writesFile
        case "rg":
            return !tokens.contains(where: { $0.hasPrefix("--pre") })
        case "sort":
            return !tokens.contains(where: { $0 == "-o" || $0.hasPrefix("--output") })
        case "date":
            return !tokens.contains("-s")
        case "xxd":
            return !tokens.contains("-r")
        default:
            return true
        }
    }

    // MARK: - 命令词提取

    private static func commandName(from tokens: [String]) -> String? {
        var index = 0
        while index < tokens.count {
            let token = tokens[index]
            if token == "!" {
                index += 1
                continue
            }
            if isEnvironmentAssignment(token) {
                index += 1
                continue
            }
            let name = (token as NSString).lastPathComponent.lowercased()
            return name.isEmpty ? nil : name
        }
        return nil
    }

    private static func isEnvironmentAssignment(_ token: String) -> Bool {
        guard let equals = token.firstIndex(of: "="), equals != token.startIndex else { return false }
        let prefix = token[token.startIndex..<equals]
        guard let first = prefix.first, first.isLetter || first == "_" else { return false }
        return prefix.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
    }

    // MARK: - 解析：引号、转义、命令链与嵌套结构

    private struct ParseResult {
        var segments: [String]
        var nested: [String]
        var malformed: Bool
    }

    /// 拆分命令链，同时收集命令替换/子 shell/分组的内层文本。
    /// 引号与转义内的分隔符不参与拆分。
    private static func parse(_ input: String) -> ParseResult {
        let chars = Array(input)
        var segments: [String] = []
        var nested: [String] = []
        var current = ""
        var quote: Character?
        var escaped = false
        var malformed = false
        var index = 0

        func flush() {
            let segment = current.trimmingCharacters(in: .whitespacesAndNewlines)
            if !segment.isEmpty { segments.append(segment) }
            current = ""
        }

        while index < chars.count {
            let char = chars[index]

            if escaped {
                current.append(char)
                escaped = false
                index += 1
                continue
            }

            if let activeQuote = quote {
                if activeQuote == "\"" && char == "\\" {
                    current.append(char)
                    escaped = true
                    index += 1
                    continue
                }
                if char == activeQuote {
                    quote = nil
                    current.append(char)
                    index += 1
                    continue
                }
                if activeQuote == "\"" {
                    if char == "$", index + 1 < chars.count, chars[index + 1] == "{" {
                        guard let consumed = consumeParameterExpansion(chars, from: index) else {
                            malformed = true
                            index = chars.count
                            break
                        }
                        current.append(contentsOf: consumed.text)
                        index = consumed.next
                        continue
                    }
                    if char == "$", index + 2 < chars.count, chars[index + 1] == "(", chars[index + 2] == "(" {
                        guard let captured = captureBalanced(chars, from: index + 1, open: "(", close: ")") else {
                            malformed = true
                            index = chars.count
                            break
                        }
                        current.append(" ")
                        index = captured.next
                        continue
                    }
                    if char == "$", index + 1 < chars.count, chars[index + 1] == "(" {
                        guard let captured = captureBalanced(chars, from: index + 1, open: "(", close: ")") else {
                            malformed = true
                            index = chars.count
                            break
                        }
                        nested.append(captured.inner)
                        current.append(" ")
                        index = captured.next
                        continue
                    }
                    if char == "`" {
                        guard let captured = captureBacktick(chars, from: index) else {
                            malformed = true
                            index = chars.count
                            break
                        }
                        nested.append(captured.inner)
                        current.append(" ")
                        index = captured.next
                        continue
                    }
                }
                current.append(char)
                index += 1
                continue
            }

            if char == "\\" {
                current.append(char)
                escaped = true
                index += 1
                continue
            }
            if char == "'" || char == "\"" {
                quote = char
                current.append(char)
                index += 1
                continue
            }
            if char == "$", index + 1 < chars.count, chars[index + 1] == "{" {
                guard let consumed = consumeParameterExpansion(chars, from: index) else {
                    malformed = true
                    index = chars.count
                    break
                }
                current.append(contentsOf: consumed.text)
                index = consumed.next
                continue
            }
            if char == "$", index + 2 < chars.count, chars[index + 1] == "(", chars[index + 2] == "(" {
                // 算术展开 $((...)) 不执行命令，保留原样即可。
                guard let captured = captureBalanced(chars, from: index + 1, open: "(", close: ")") else {
                    malformed = true
                    index = chars.count
                    break
                }
                current.append(" ")
                index = captured.next
                continue
            }
            if char == "$", index + 1 < chars.count, chars[index + 1] == "(" {
                guard let captured = captureBalanced(chars, from: index + 1, open: "(", close: ")") else {
                    malformed = true
                    index = chars.count
                    break
                }
                nested.append(captured.inner)
                current.append(" ")
                index = captured.next
                continue
            }
            if char == "`" {
                guard let captured = captureBacktick(chars, from: index) else {
                    malformed = true
                    index = chars.count
                    break
                }
                nested.append(captured.inner)
                current.append(" ")
                index = captured.next
                continue
            }
            if char == "(" || char == "{" {
                let close: Character = char == "(" ? ")" : "}"
                guard let captured = captureBalanced(chars, from: index, open: char, close: close) else {
                    malformed = true
                    index = chars.count
                    break
                }
                nested.append(captured.inner)
                current.append(" ")
                index = captured.next
                continue
            }
            if char == "|" || char == ";" || char == "\n" || char == "\r" {
                flush()
                index += 1
                continue
            }
            if char == "&" {
                let previous = index > 0 ? chars[index - 1] : " "
                let next = index + 1 < chars.count ? chars[index + 1] : " "
                if previous == ">" || next == ">" || next == "&" {
                    current.append(char)
                    index += 1
                    continue
                }
                flush()
                index += 1
                continue
            }

            current.append(char)
            index += 1
        }

        if escaped || quote != nil { malformed = true }
        flush()
        return ParseResult(segments: segments, nested: nested, malformed: malformed)
    }

    /// 从 `open` 位置开始捕获到匹配的 `close`，返回内层文本与闭合后的下标。
    private static func captureBalanced(
        _ chars: [Character],
        from start: Int,
        open: Character,
        close: Character
    ) -> (inner: String, next: Int)? {
        var depth = 1
        var quote: Character?
        var escaped = false
        var index = start + 1

        while index < chars.count {
            let char = chars[index]
            if escaped {
                escaped = false
                index += 1
                continue
            }
            if let activeQuote = quote {
                if activeQuote == "\"" && char == "\\" {
                    escaped = true
                } else if char == activeQuote {
                    quote = nil
                }
                index += 1
                continue
            }
            if char == "\\" {
                escaped = true
                index += 1
                continue
            }
            if char == "'" || char == "\"" {
                quote = char
                index += 1
                continue
            }
            if char == open {
                depth += 1
            } else if char == close {
                depth -= 1
                if depth == 0 {
                    let inner = String(chars[(start + 1)..<index])
                    return (inner, index + 1)
                }
            }
            index += 1
        }
        return nil
    }

    /// 保留 `${...}` 参数展开原样，避免把变量名误当成命令或丢失敏感路径。
    private static func consumeParameterExpansion(_ chars: [Character], from start: Int) -> (text: [Character], next: Int)? {
        var depth = 1
        var index = start + 2
        while index < chars.count {
            if chars[index] == "{" {
                depth += 1
            } else if chars[index] == "}" {
                depth -= 1
                if depth == 0 {
                    return (Array(chars[start...index]), index + 1)
                }
            }
            index += 1
        }
        return nil
    }

    private static func captureBacktick(_ chars: [Character], from start: Int) -> (inner: String, next: Int)? {
        var index = start + 1
        var escaped = false
        while index < chars.count {
            let char = chars[index]
            if escaped {
                escaped = false
                index += 1
                continue
            }
            if char == "\\" {
                escaped = true
                index += 1
                continue
            }
            if char == "`" {
                return (String(chars[(start + 1)..<index]), index + 1)
            }
            index += 1
        }
        return nil
    }

    /// 按引号与转义规则切词；引号本身不进入结果。
    private static func words(in text: String) -> [String] {
        var result: [String] = []
        var current = ""
        var hasContent = false
        var quote: Character?
        var escaped = false

        for char in text {
            if escaped {
                current.append(char)
                hasContent = true
                escaped = false
                continue
            }
            if let activeQuote = quote {
                if activeQuote == "\"" && char == "\\" {
                    escaped = true
                    continue
                }
                if char == activeQuote {
                    quote = nil
                    continue
                }
                current.append(char)
                hasContent = true
                continue
            }
            if char == "\\" {
                escaped = true
                continue
            }
            if char == "'" || char == "\"" {
                quote = char
                hasContent = true
                continue
            }
            if char.isWhitespace {
                if hasContent {
                    result.append(current)
                    current = ""
                    hasContent = false
                }
                continue
            }
            current.append(char)
            hasContent = true
        }
        if hasContent { result.append(current) }
        return result
    }

    /// 引号内的字符串字面量，用于解释器内层递归分析。
    private static func quotedLiterals(in text: String) -> [String] {
        var result: [String] = []
        var index = text.startIndex
        while index < text.endIndex {
            let char = text[index]
            guard char == "'" || char == "\"" else {
                index = text.index(after: index)
                continue
            }
            let quote = char
            var literal = ""
            var cursor = text.index(after: index)
            var escaped = false
            var closed = false
            while cursor < text.endIndex {
                let inner = text[cursor]
                if escaped {
                    literal.append(inner)
                    escaped = false
                } else if quote == "\"" && inner == "\\" {
                    escaped = true
                } else if inner == quote {
                    closed = true
                    cursor = text.index(after: cursor)
                    break
                } else {
                    literal.append(inner)
                }
                cursor = text.index(after: cursor)
            }
            if closed { result.append(literal) }
            index = cursor
        }
        return result
    }

    // MARK: - 重定向

    /// 检测非 `/dev/null` 的写重定向（`>`、`>>`、`&>`）；`2>&1` 之类的 fd 复制不算。
    private static func hasDangerousRedirection(_ text: String) -> Bool {
        let chars = Array(text)
        var index = 0
        var quote: Character?
        var escaped = false

        while index < chars.count {
            let char = chars[index]
            if escaped {
                escaped = false
                index += 1
                continue
            }
            if let activeQuote = quote {
                if activeQuote == "\"" && char == "\\" {
                    escaped = true
                } else if char == activeQuote {
                    quote = nil
                }
                index += 1
                continue
            }
            if char == "\\" {
                escaped = true
                index += 1
                continue
            }
            if char == "'" || char == "\"" {
                quote = char
                index += 1
                continue
            }
            guard char == ">" else {
                index += 1
                continue
            }

            var cursor = index + 1
            if cursor < chars.count, chars[cursor] == ">" { cursor += 1 }
            if cursor < chars.count, chars[cursor] == "&" {
                // >&1 / >&- ：文件描述符复制，不是文件写入
                index = cursor + 1
                continue
            }
            while cursor < chars.count, chars[cursor].isWhitespace { cursor += 1 }
            var target = ""
            var targetQuote: Character?
            while cursor < chars.count {
                let targetChar = chars[cursor]
                if targetQuote == nil, targetChar.isWhitespace || targetChar == "|" || targetChar == ";" || targetChar == "&" {
                    break
                }
                if targetChar == "'" || targetChar == "\"" {
                    let active = targetQuote
                    if active == nil {
                        targetQuote = targetChar
                    } else if active == targetChar {
                        targetQuote = nil
                    }
                } else {
                    target.append(targetChar)
                }
                cursor += 1
            }
            let normalized = target.trimmingCharacters(in: .whitespacesAndNewlines)
            if normalized != "/dev/null" { return true }
            index = cursor
        }
        return false
    }

    private static func add(_ reason: String, _ reasons: inout [String]) {
        if !reasons.contains(reason) { reasons.append(reason) }
    }
}
