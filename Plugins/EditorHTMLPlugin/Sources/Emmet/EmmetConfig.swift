import Foundation

/// Emmet 配置
///
/// 管理 Emmet 引擎的行为配置，包括变量和语法配置文件。
public enum EmmetConfig {
    // MARK: - 默认变量

    /// 默认使用的变量映射
    public static let defaultVariables: [String: String] = [
        "lang": "zh-CN",
        "charset": "UTF-8",
        "locale": "zh-CN",
    ]

    // MARK: - 语法配置

    /// 不同语法的缩进配置
    public static let indentStyle: String = "  " // 两空格缩进

    /// 是否启用 inline 模式（单行输出）
    public static let inlineMode: Bool = false

    // MARK: - 标签别名

    /// 常见的 Emmet 标签别名
    public static let aliases: [String: String] = [
        "cc:ie6": "<!--[if lte IE 6]>\n${0}\n<![endif]-->",
        "cc:ie": "<!--[if IE]>\n${0}\n<![endif]-->",
        "link:css": "<link rel=\"stylesheet\" href=\"style.css\">",
        "link:print": "<link rel=\"stylesheet\" href=\"print.css\" media=\"print\">",
        "link:favicon": "<link rel=\"shortcut icon\" type=\"image/x-icon\" href=\"favicon.ico\">",
        "link:touch": "<link rel=\"apple-touch-icon\" href=\"favicon.png\">",
        "meta:vp": "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">",
        "meta:charset": "<meta charset=\"UTF-8\">",
        "meta:compat": "<meta http-equiv=\"X-UA-Compatible\" content=\"IE=edge\">",
    ]

    // MARK: - HTML 模板

    /// HTML5 基础模板
    public static let html5Template = """
<!DOCTYPE html>
<html lang="${lang}">
<head>
\t<meta charset="${charset}">
\t<meta name="viewport" content="width=device-width, initial-scale=1.0">
\t<title>Document</title>
</head>
<body>
\t${0}
</body>
</html>
"""

    // MARK: - JSX 配置

    /// JSX 模式下使用 className 而非 class
    public static let jsxMode: Bool = false

    // MARK: - 方法

    /// 获取展开语法模式
    public static func syntaxMode(for languageId: String) -> EmmetSyntax {
        if languageId.lowercased().contains("jsx") || languageId.lowercased().contains("tsx") {
            return .jsx
        }
        return .html
    }

    /// 检查是否为有效的 Emmet 触发上下文
    ///
    /// 在 `<script>` 或 `<style>` 块内应禁用 HTML Emmet
    public static func isEnabled(at context: EmmetContext) -> Bool {
        switch context {
        case .html:
            return true
        case .css:
            // CSS Emmet 应由 CSS 插件处理
            return false
        case .javascript:
            // JS Emmet 应由 JS 插件处理
            return false
        }
    }
}

/// Emmet 上下文
public enum EmmetContext {
    case html
    case css
    case javascript
}
