import Foundation
import KitAgentTool

// MARK: - Booklet Tool Support

/// Booklet Maker Agent 工具的共享支持逻辑。
///
/// 工具层只做三件事：解析参数、解析路径、格式化结果。所有 PDF 处理
/// 都复用插件已有的服务（`PDFInspector` / `BookletRenderer` /
/// `PDFSplitter` / `BookletThumbnailer` / `BookletLayoutEngine`），
/// 不引入第二套渲染实现。
///
/// 与 `PromoToolSupport`、`IconToolSupport` 的差异：Booklet Maker 是
/// 纯文件工具，不依赖项目作用域，因此工具直接接收绝对路径。
enum BookletToolSupport {

    /// 当前语言偏好（跟随系统 locale）。
    static var language: LanguagePreference { .current }

    // MARK: - 路径

    /// 读取必填路径参数，展开 `~` 并转为文件 URL。
    static func requiredPath(_ key: String, _ arguments: [String: ToolArgument]) throws -> URL {
        fileURL(try required(key, arguments))
    }

    /// 读取可选路径参数；空字符串视为未提供。
    static func optionalPath(_ key: String, _ arguments: [String: ToolArgument]) -> URL? {
        guard let raw = string(arguments, key)?
            .trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        return fileURL(raw)
    }

    static func fileURL(_ raw: String) -> URL {
        URL(fileURLWithPath: (raw as NSString).expandingTildeInPath)
    }

    /// 插件数据目录下的暂存目录；插件尚未 boot（如独立测试）时回退到系统临时目录。
    static func stagingDirectory(named name: String) -> URL {
        let base = BookletMakerRuntimeBridge.directoryURL
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return base.appendingPathComponent(name, isDirectory: true)
    }

    // MARK: - 参数访问器

    static func required(_ key: String, _ arguments: [String: ToolArgument]) throws -> String {
        guard let value = string(arguments, key)?
            .trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            throw ToolArgumentError.missing(key)
        }
        return value
    }

    static func string(_ arguments: [String: ToolArgument], _ key: String) -> String? {
        guard let value = arguments[key]?.value else { return nil }
        if let string = value as? String { return string }
        if let number = value as? NSNumber { return number.stringValue }
        return nil
    }

    static func bool(_ arguments: [String: ToolArgument],
                     _ key: String,
                     default defaultValue: Bool) -> Bool {
        guard let value = arguments[key]?.value else { return defaultValue }
        if let bool = value as? Bool { return bool }
        if let number = value as? NSNumber { return number.boolValue }
        if let string = value as? String { return Bool(string) ?? defaultValue }
        return defaultValue
    }

    static func double(_ arguments: [String: ToolArgument],
                       _ key: String,
                       default defaultValue: Double) -> Double {
        guard let value = arguments[key]?.value else { return defaultValue }
        if let double = value as? Double { return double }
        if let int = value as? Int { return Double(int) }
        if let number = value as? NSNumber { return number.doubleValue }
        if let string = value as? String, let double = Double(string) { return double }
        return defaultValue
    }

    static func int(_ arguments: [String: ToolArgument], _ key: String) -> Int? {
        guard let value = arguments[key]?.value else { return nil }
        if let int = value as? Int { return int }
        if let double = value as? Double { return Int(double) }
        if let number = value as? NSNumber { return number.intValue }
        if let string = value as? String { return Int(string) }
        return nil
    }

    /// 解析整型数组参数；同时容忍 `"20, 50, 80"` 这类分隔字符串写法。
    static func intArray(_ arguments: [String: ToolArgument], _ key: String) -> [Int]? {
        guard let value = arguments[key]?.value else { return nil }
        if let numbers = value as? [Int], !numbers.isEmpty { return numbers }
        if let values = value as? [Any] {
            let ints = values.compactMap { item -> Int? in
                if let int = item as? Int { return int }
                if let number = item as? NSNumber { return number.intValue }
                if let string = item as? String {
                    return Int(string.trimmingCharacters(in: .whitespaces))
                }
                return nil
            }
            return ints.isEmpty ? nil : ints
        }
        if let string = value as? String {
            let ints = string
                .replacingOccurrences(of: "，", with: ",")
                .split { $0 == "," || $0.isWhitespace }
                .compactMap { Int($0) }
            return ints.isEmpty ? nil : ints
        }
        return nil
    }

    // MARK: - 拼版设置

    /// 从工具参数构造 `BookletSettings`，未提供的字段沿用默认值。
    static func settings(_ arguments: [String: ToolArgument]) throws -> BookletSettings {
        var settings = BookletSettings()

        if let raw = trimmed(arguments, "paper") {
            guard let paper = PaperSize(rawValue: raw.lowercased()) else {
                throw ToolArgumentError.invalid("paper")
            }
            settings.outputPaper = paper
        }

        // LayoutMode 的 rawValue 是驼峰（simplePair / bookletFold），
        // 不能先 lowercased 再匹配，否则永远解析失败。
        if let raw = trimmed(arguments, "layout") {
            guard let layout = LayoutMode.allCases.first(where: {
                $0.rawValue.caseInsensitiveCompare(raw) == .orderedSame
            }) else {
                throw ToolArgumentError.invalid("layout")
            }
            settings.layout = layout
        }

        settings.marginMM = double(arguments, "marginMM", default: settings.marginMM)
        settings.gutterMM = double(arguments, "gutterMM", default: settings.gutterMM)
        settings.padBlankPage = bool(arguments, "padBlankPage", default: settings.padBlankPage)
        settings.addCutMarks = bool(arguments, "addCutMarks", default: settings.addCutMarks)
        return settings
    }

    /// 取出已 trim 的字符串参数；缺失或全空白时返回 `nil`。
    static func trimmed(_ arguments: [String: ToolArgument], _ key: String) -> String? {
        guard let value = string(arguments, key)?
            .trimmingCharacters(in: .whitespacesAndNewlines) else { return nil }
        return value.isEmpty ? nil : value
    }

    /// 构造设置并做几何合法性校验（负边距 / 负间距会让页面格宽度非正）。
    static func validatedSettings(_ arguments: [String: ToolArgument]) throws -> BookletSettings {
        let settings = try settings(arguments)
        guard settings.marginMM >= 0, settings.gutterMM >= 0 else {
            throw ToolArgumentError.invalid("marginMM / gutterMM must be >= 0")
        }
        guard settings.cellWidthInPoints() > 0, settings.cellHeightInPoints() > 0 else {
            throw ToolArgumentError.invalid("paper / marginMM / gutterMM leave no room for a page cell")
        }
        return settings
    }

    // MARK: - Schema 辅助

    static func schema(_ properties: [String: Any], required keys: [String] = []) -> [String: Any] {
        ["type": "object", "properties": properties, "required": keys]
    }

    static func pathProperty(_ description: String) -> [String: Any] {
        ["type": "string", "description": description]
    }

    /// 拼版参数（纸张、布局、边距、间距、补白、裁切标记）的通用 schema 片段。
    static func settingsProperties() -> [String: Any] {
        [
            "paper": [
                "type": "string",
                "enum": PaperSize.allCases.map(\.rawValue),
                "description": "Output paper size. Defaults to a4.",
            ],
            "layout": [
                "type": "string",
                "enum": LayoutMode.allCases.map(\.rawValue),
                "description": "bookletFold (default) imposes pages so duplex printing + folding yields a correctly ordered booklet; simplePair keeps document order on one side.",
            ],
            "marginMM": [
                "type": "number",
                "description": "Outer margin on all four sides in millimetres. Defaults to 5.",
            ],
            "gutterMM": [
                "type": "number",
                "description": "Inner gutter between the two page cells in millimetres. Defaults to 5.",
            ],
            "padBlankPage": [
                "type": "boolean",
                "description": "Pad the source with blank pages so the count fits the layout. Defaults to true.",
            ],
            "addCutMarks": [
                "type": "boolean",
                "description": "Draw small corner tick marks as trimming guides. Defaults to true.",
            ],
        ]
    }

    // MARK: - 结果格式化

    /// 页面编号展示：`0` 表示留白格。
    static func pageLabel(_ page: Int) -> String {
        page > 0 ? "\(page)" : "blank"
    }

    static func millimetres(_ points: Double) -> String {
        String(format: "%.1f", PaperSize.ptToMM(points))
    }

    /// 人类可读的拼版计划：物理纸张数、印刷面数，以及逐面页序映射。
    static func planDescription(inputPageCount: Int,
                                settings: BookletSettings,
                                maxSides: Int = 24) -> String {
        let sheets = BookletLayoutEngine.buildPhysicalSheets(
            inputPageCount: inputPageCount,
            settings: settings
        )
        let sides = BookletLayoutEngine.buildOutputSides(
            inputPageCount: inputPageCount,
            settings: settings
        )
        guard !sheets.isEmpty else { return "Plan: empty (no source pages)." }

        var lines: [String] = []
        lines.append("Layout: \(settings.layout.rawValue) · paper: \(settings.outputPaper.displayName) · margin: \(settings.marginMM)mm · gutter: \(settings.gutterMM)mm")
        lines.append("Source pages: \(inputPageCount) → physical sheets: \(sheets.count) · print sides: \(sides.count)")

        for sheet in sheets.prefix(max(1, maxSides / 2)) {
            let front = "Sheet \(sheet.index + 1) front: \(pageLabel(sheet.front.leftPage)) | \(pageLabel(sheet.front.rightPage))"
            lines.append(front)
            if let back = sheet.back {
                lines.append("Sheet \(sheet.index + 1) back:  \(pageLabel(back.leftPage)) | \(pageLabel(back.rightPage))")
            }
        }
        if sheets.count * 2 > maxSides {
            lines.append("… \(sheets.count * 2 - maxSides) more print sides omitted")
        }
        return lines.joined(separator: "\n")
    }

    /// 拆分段列表：`1) Pages 1–20 → name.pdf`。
    static func segmentsDescription(_ outputs: [PDFSplitOutput]) -> String {
        guard !outputs.isEmpty else { return "No split segments." }
        return outputs
            .map { "\($0.segment.index)) \($0.segment.rangeLabel) → \($0.fileName)" }
            .joined(separator: "\n")
    }

    // MARK: - 本地化

    static func localized(_ language: LanguagePreference, en: String, zh: String) -> String {
        switch language {
        case .chinese: zh
        case .english: en
        }
    }

    static func error(_ error: Error, language: LanguagePreference) -> String {
        localized(
            language,
            en: "Error: \(error.localizedDescription)",
            zh: "错误：\(localizedErrorDescription(error.localizedDescription))"
        )
    }

    static func missingParameter(_ name: String, language: LanguagePreference) -> String {
        localized(
            language,
            en: "Error: Missing required '\(name)' parameter.",
            zh: "错误：缺少必填参数 '\(name)'。"
        )
    }

    /// 把工具层自己抛出的英文错误描述翻译为中文。
    ///
    /// 服务层错误（`PDFInspector` / `BookletRenderer` / `PDFSplitter`）已通过
    /// `BookletLocalization` 本地化，这里只处理参数校验与包装类错误。
    static func localizedErrorDescription(_ description: String) -> String {
        if let suffix = description.dropPrefix("Missing required argument: ") {
            return "缺少必填参数：\(suffix)"
        }
        if let suffix = description.dropPrefix("Invalid argument: ") {
            return "无效参数：\(suffix)"
        }
        if let suffix = description.dropPrefix("Output file already exists: ") {
            return "输出文件已存在：\(suffix)"
        }
        if description == "Source PDF has no renderable pages." {
            return "源 PDF 没有可渲染的页面。"
        }
        return description
    }

    // MARK: - Errors

    enum ToolArgumentError: LocalizedError {
        case missing(String)
        case invalid(String)

        var errorDescription: String? {
            switch self {
            case .missing(let key): "Missing required argument: \(key)"
            case .invalid(let key): "Invalid argument: \(key)"
            }
        }
    }
}

extension String {
    /// 空字符串归一化为 `nil`，便于 `??` 回退到默认值。
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }

    /// 命中前缀时返回去掉前缀的部分，否则返回 `nil`。
    func dropPrefix(_ prefix: String) -> Substring? {
        guard hasPrefix(prefix) else { return nil }
        return dropFirst(prefix.count)
    }
}
