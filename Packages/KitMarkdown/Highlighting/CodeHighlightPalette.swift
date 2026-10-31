import SwiftUI

/// 语法着色调色板。
///
/// capture 名来自 tree-sitter 高亮查询（`keyword`、`function.call` 等），
/// 这里按基名（点号前的部分）映射到颜色；未知 capture 不着色。
struct CodeHighlightPalette {

    let identifier: String
    let keyword: Color
    let string: Color
    let number: Color
    let boolean: Color
    let comment: Color
    let function: Color
    let type: Color
    let variable: Color
    let constant: Color
    let property: Color
    let attribute: Color
    let `operator`: Color
    let punctuation: Color
    let tag: Color
    let markup: Color

    /// capture 名 → 颜色。
    ///
    /// capture 名可能带后缀（`function.call`、`keyword.modifier`），按基名归类；
    /// 未识别的 capture 返回 `nil`，保持正文默认色。
    func color(forCapture capture: String) -> Color? {
        let base = capture.split(separator: ".").first.map(String.init) ?? capture
        switch base {
        case "keyword": return keyword
        case "string": return string
        case "number", "float", "integer": return number
        case "boolean": return boolean
        case "comment": return comment
        case "function", "method": return function
        case "type", "class", "struct", "enum", "interface", "namespace": return type
        case "variable", "parameter": return variable
        case "constant": return constant
        case "property": return property
        case "attribute", "label": return attribute
        case "operator": return `operator`
        case "punctuation": return punctuation
        case "tag": return tag
        case "markup": return markup
        default: return nil
        }
    }

    // MARK: - 内置配色

    /// 浅色配色（对齐 GitHub Light 的观感）。
    static let light = CodeHighlightPalette(
        identifier: "light",
        keyword: Color(red: 0.81, green: 0.13, blue: 0.18),
        string: Color(red: 0.04, green: 0.19, blue: 0.41),
        number: Color(red: 0.02, green: 0.31, blue: 0.68),
        boolean: Color(red: 0.02, green: 0.31, blue: 0.68),
        comment: Color(red: 0.43, green: 0.47, blue: 0.51),
        function: Color(red: 0.51, green: 0.31, blue: 0.87),
        type: Color(red: 0.58, green: 0.22, blue: 0.00),
        variable: Color(red: 0.58, green: 0.22, blue: 0.00),
        constant: Color(red: 0.02, green: 0.31, blue: 0.68),
        property: Color(red: 0.02, green: 0.31, blue: 0.68),
        attribute: Color(red: 0.02, green: 0.31, blue: 0.68),
        operator: Color(red: 0.36, green: 0.15, blue: 0.20),
        punctuation: Color(red: 0.36, green: 0.40, blue: 0.45),
        tag: Color(red: 0.11, green: 0.41, blue: 0.22),
        markup: Color(red: 0.58, green: 0.22, blue: 0.00)
    )

    /// 深色配色（对齐 GitHub Dark 的观感）。
    static let dark = CodeHighlightPalette(
        identifier: "dark",
        keyword: Color(red: 1.00, green: 0.48, blue: 0.45),
        string: Color(red: 0.65, green: 0.84, blue: 1.00),
        number: Color(red: 0.47, green: 0.75, blue: 1.00),
        boolean: Color(red: 0.47, green: 0.75, blue: 1.00),
        comment: Color(red: 0.55, green: 0.58, blue: 0.62),
        function: Color(red: 0.82, green: 0.66, blue: 1.00),
        type: Color(red: 1.00, green: 0.65, blue: 0.34),
        variable: Color(red: 1.00, green: 0.65, blue: 0.34),
        constant: Color(red: 0.47, green: 0.75, blue: 1.00),
        property: Color(red: 0.47, green: 0.75, blue: 1.00),
        attribute: Color(red: 0.47, green: 0.75, blue: 1.00),
        operator: Color(red: 0.85, green: 0.45, blue: 0.45),
        punctuation: Color(red: 0.65, green: 0.68, blue: 0.72),
        tag: Color(red: 0.40, green: 0.80, blue: 0.46),
        markup: Color(red: 1.00, green: 0.65, blue: 0.34)
    )

    /// 按外观取配色。
    static func palette(for colorScheme: ColorScheme) -> CodeHighlightPalette {
        colorScheme == .dark ? .dark : .light
    }
}
