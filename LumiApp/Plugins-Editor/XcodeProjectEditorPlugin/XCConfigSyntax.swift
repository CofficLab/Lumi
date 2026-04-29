import Foundation
import AppKit

/// XCConfig 语法高亮和编辑支持
/// 对应 Phase 7: xcconfig 语法与跳转
enum XCConfigSyntax {
    
    /// 标记类型
    enum TokenType: String {
        case comment = "comment"
        case include = "include"
        case key = "key"
        case value = "value"
        case operator_symbol = "operator"
        case preprocessor = "preprocessor"
        case string = "string"
    }
    
    /// 语法标记
    struct Token {
        let type: TokenType
        let range: NSRange
    }
    
    /// 解析 xcconfig 文件的语法标记
    static func tokenize(_ content: String) -> [Token] {
        var tokens: [Token] = []
        let nsContent = content as NSString
        
        // 注释: // 或 /* */
        let commentPattern = "(?://[^\\n]*)|(?:/\\*[\\s\\S]*?\\*/)"
        addTokens(for: commentPattern, in: content, nsContent: nsContent, type: .comment, to: &tokens)
        
        // Include 语句: #include? "path"
        let includePattern = "^\\s*#include(?:_once)?\\s+\"([^\"]+)\""
        addTokens(for: includePattern, in: content, nsContent: nsContent, type: .include, to: &tokens)
        
        // 键值对: KEY = VALUE
        let keyValuePattern = "^\\s*([A-Za-z_][A-Za-z0-9_]*)\\s*([=+-]=?)\\s*(.+)$"
        if let regex = try? NSRegularExpression(pattern: keyValuePattern, options: .anchorsMatchLines) {
            regex.enumerateMatches(in: content, range: NSRange(location: 0, length: content.utf16.count)) { match, _, _ in
                guard let match else { return }
                // Key
                let keyRange = match.range(at: 1)
                if keyRange.location != NSNotFound {
                    tokens.append(Token(type: .key, range: keyRange))
                }
                // Operator
                let opRange = match.range(at: 2)
                if opRange.location != NSNotFound {
                    tokens.append(Token(type: .operator_symbol, range: opRange))
                }
                // Value
                let valueRange = match.range(at: 3)
                if valueRange.location != NSNotFound {
                    tokens.append(Token(type: .value, range: valueRange))
                }
            }
        }
        
        // 变量引用: $(VAR) 或 ${VAR}
        let variablePattern = "\\$[({][A-Za-z_][A-Za-z0-9_]*[)}]"
        addTokens(for: variablePattern, in: content, nsContent: nsContent, type: .preprocessor, to: &tokens)
        
        // 引号字符串
        let stringPattern = "\"[^\"]*\""
        addTokens(for: stringPattern, in: content, nsContent: nsContent, type: .string, to: &tokens)
        
        return tokens.sorted { $0.range.location < $1.range.location }
    }
    
    private static func addTokens(for pattern: String, in content: String, nsContent: NSString, type: TokenType, to tokens: inout [Token]) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .anchorsMatchLines) else { return }
        regex.enumerateMatches(in: content, range: NSRange(location: 0, length: content.utf16.count)) { match, _, _ in
            guard let match else { return }
            let range = match.range(at: 0)
            tokens.append(Token(type: type, range: range))
        }
    }
    
    /// 应用语法高亮到 text storage
    static func applyHighlighting(to textStorage: NSTextStorage, range: NSRange) {
        let content = textStorage.string
        let tokens = tokenize(content)
        
        for token in tokens where NSIntersectionRange(token.range, range).length > 0 {
            let color: NSColor
            let fontAttribute: [NSAttributedString.Key: Any]
            
            switch token.type {
            case .comment:
                color = NSColor.systemGray
                fontAttribute = [.foregroundColor: color]
            case .include:
                color = NSColor.systemPurple
                fontAttribute = [.foregroundColor: color]
            case .key:
                color = NSColor.systemBlue
                fontAttribute = [.foregroundColor: color, .font: NSFont.systemFont(ofSize: NSFont.systemFontSize, weight: .medium)]
            case .value:
                color = NSColor.systemOrange
                fontAttribute = [.foregroundColor: color]
            case .operator_symbol:
                color = NSColor.systemRed
                fontAttribute = [.foregroundColor: color]
            case .preprocessor:
                color = NSColor.systemCyan
                fontAttribute = [.foregroundColor: color]
            case .string:
                color = NSColor.systemGreen
                fontAttribute = [.foregroundColor: color]
            }
            
            textStorage.addAttributes(fontAttribute, range: token.range)
        }
    }
}

/// XCConfig 验证器
enum XCConfigValidator {
    
    struct Issue: Identifiable {
        let id = UUID()
        let line: Int
        let message: String
        let severity: Severity
        
        enum Severity {
            case warning, error
        }
    }
    
    /// 验证 xcconfig 内容
    static func validate(_ content: String) -> [Issue] {
        var issues: [Issue] = []
        let lines = content.components(separatedBy: .newlines)
        
        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // 跳过空行和注释
            if trimmed.isEmpty || trimmed.hasPrefix("//") || trimmed.hasPrefix("/*") {
                continue
            }
            
            // 检查 include 语句格式
            if trimmed.hasPrefix("#include") || trimmed.hasPrefix("#include_once") {
                if !trimmed.contains("\"") {
                    issues.append(Issue(line: index + 1, message: "Include 语句需要引号包裹路径", severity: .error))
                }
                continue
            }
            
            // 检查键值对格式
            if !trimmed.contains("=") {
                issues.append(Issue(line: index + 1, message: "无效的键值对格式", severity: .warning))
            }
        }
        
        return issues
    }
}
