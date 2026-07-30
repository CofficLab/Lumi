import LumiKernel
import LumiUI
import os
import SuperLogKit
import SwiftUI

/// JSON 文件预览视图。
///
/// 以可折叠树形结构展示 JSON 数据，支持 JSONL（每行一个 JSON 对象）。
public struct EditorPreviewJSONView: View, SuperLog {
    public nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.editor-inline-preview.json-view"
    )
    public nonisolated static let emoji = "📋"
    public nonisolated static let verbose: Bool = true

    @EnvironmentObject private var themeVM: AppThemeVM

    public let jsonText: String

    public var body: some View {
        Group {
            if jsonText.isEmpty {
                emptyView
            } else {
                switch JSONPreviewParser.parse(jsonText) {
                case let .success(value):
                    jsonScrollView(value)
                case let .failure(error):
                    errorView(error)
                }
            }
        }
        .background(themeVM.activeChromeTheme.workspaceBackgroundColor())
    }

    // MARK: - 视图

    private var emptyView: some View {
        VStack(spacing: 10) {
            Image(systemName: "curlybraces")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text(LumiPluginLocalization.string("No JSON content to preview.", bundle: .module))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 240)
        .padding(24)
    }

    private func errorView(_ error: Error) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28))
                .foregroundStyle(.orange)
            Text(LumiPluginLocalization.string("Invalid JSON", bundle: .module))
                .font(.headline)
                .foregroundStyle(.primary)
            Text(error.localizedDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 240)
        .padding(24)
    }

    private func jsonScrollView(_ value: Any) -> some View {
        ScrollView([.horizontal, .vertical]) {
            JSONTreeNode(
                key: nil,
                value: value,
                depth: 0,
                theme: themeVM.activeChromeTheme
            )
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - JSON 解析

enum JSONPreviewParser {
    static func parse(_ text: String) -> Result<Any, Error> {
        let trimmed = stripByteOrderMark(from: text).trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8) else {
            return .failure(JSONParseError.invalidData)
        }

        do {
            let value = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
            return .success(value)
        } catch let standardJSONError {
            do {
                let jsonlResult = try parseJSONL(trimmed)
                if jsonlResult.count > 1 {
                    return .success(jsonlResult)
                }
                return .failure(standardJSONError)
            } catch JSONParseError.invalidJSONLLine(1) {
                return .failure(standardJSONError)
            } catch {
                return .failure(error)
            }
        }
    }

    private static func parseJSONL(_ text: String) throws -> [Any] {
        var results: [Any] = []

        for (index, line) in text.components(separatedBy: .newlines).enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            guard let data = trimmed.data(using: .utf8) else {
                throw JSONParseError.invalidJSONLLine(index + 1)
            }

            do {
                let value = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
                results.append(value)
            } catch {
                throw JSONParseError.invalidJSONLLine(index + 1)
            }
        }

        return results
    }

    private static func stripByteOrderMark(from text: String) -> String {
        guard text.first == "\u{FEFF}" else { return text }
        return String(text.dropFirst())
    }
}

enum JSONParseError: LocalizedError, Equatable {
    case invalidData
    case invalidJSONLLine(Int)

    var errorDescription: String? {
        switch self {
        case .invalidData:
            return LumiPluginLocalization.string("Invalid JSON data", bundle: .module)
        case let .invalidJSONLLine(line):
            return LumiPluginLocalization.string("Invalid JSONL at line \(line)", bundle: .module)
        }
    }
}

// MARK: - JSON 树节点

private struct JSONTreeNode: View {
    public let key: String?
    public let value: Any
    public let depth: Int
    public let theme: any LumiAppChromeTheme

    @State private var isExpanded: Bool

    public init(key: String?, value: Any, depth: Int, theme: any LumiAppChromeTheme) {
        self.key = key
        self.value = value
        self.depth = depth
        self.theme = theme
        // 浅层默认展开，深层默认折叠
        self._isExpanded = State(initialValue: depth < 3)
    }

    private static let maxInlineLength = 80

    public var body: some View {
        if isCollection {
            collectionNode
        } else {
            leafNode
        }
    }

    // MARK: - 集合节点（对象/数组）

    @ViewBuilder
    private var collectionNode: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 折叠状态的一行预览
            headerRow

            if isExpanded {
                expandedContent
            }
        }
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            // 缩进
            indentSpacer

            // 展开/折叠按钮
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isExpanded.toggle()
                }
            } label: {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(theme.workspaceSecondaryTextColor())
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.plain)

            // Key 名称
            if let key {
                Text("\"\(key)\"")
                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                    .foregroundColor(Self.keyColor)
                Text(verbatim: LumiPluginLocalization.string(": ", bundle: .module))
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(theme.workspaceSecondaryTextColor())
            }

            // 类型标记
            let (typeName, _) = collectionInfo
            Text(typeName)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(theme.workspaceSecondaryTextColor())

            if !isExpanded {
                // 折叠时显示简略内容
                Text(" \(collapsedPreview)")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(theme.workspaceSecondaryTextColor())
                    .lineLimit(1)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.15)) {
                isExpanded.toggle()
            }
        }
    }

    @ViewBuilder
    private var expandedContent: some View {
        if let dict = value as? [String: Any] {
            ForEach(Array(dict.keys.sorted()), id: \.self) { childKey in
                if let childValue = dict[childKey] {
                    JSONTreeNode(
                        key: childKey,
                        value: childValue,
                        depth: depth + 1,
                        theme: theme
                    )
                }
            }
        } else if let array = value as? [Any] {
            ForEach(Array(array.enumerated()), id: \.offset) { index, childValue in
                JSONTreeNode(
                    key: "[\(index)]",
                    value: childValue,
                    depth: depth + 1,
                    theme: theme
                )
            }
        }

        // 闭合括号
        HStack(spacing: 0) {
            indentSpacer
            Text(closingBracket)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(theme.workspaceSecondaryTextColor())
        }
    }

    // MARK: - 叶子节点

    private var leafNode: some View {
        HStack(spacing: 0) {
            indentSpacer
            // 占位空间（与展开按钮对齐）
            Color.clear.frame(width: 16, height: 16)

            if let key {
                Text("\"\(key)\"")
                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                    .foregroundColor(Self.keyColor)
                Text(verbatim: LumiPluginLocalization.string(": ", bundle: .module))
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(theme.workspaceSecondaryTextColor())
            }

            Text(formattedLeafValue)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(leafValueColor)
                .textSelection(.enabled)
        }
    }

    // MARK: - 辅助

    private var isCollection: Bool {
        (value as? [String: Any]) != nil || (value as? [Any]) != nil
    }

    private var collectionInfo: (String, Int) {
        if let dict = value as? [String: Any] {
            return ("{…}", dict.count)
        } else if let array = value as? [Any] {
            return ("[…]", array.count)
        }
        return ("", 0)
    }

    private var collapsedPreview: String {
        let (_, count) = collectionInfo
        let suffix = count == 1 ? "item" : "items"
        return "\(count) \(suffix)"
    }

    private var closingBracket: String {
        if (value as? [String: Any]) != nil {
            return "}"
        }
        return "]"
    }

    private var indentSpacer: some View {
        Color.clear.frame(width: CGFloat(depth) * 20, height: 1)
    }

    private static let keyColor = Color(red: 0.8, green: 0.15, blue: 0.4) // 粉紫色

    private var leafValueColor: Color {
        if value is NSNull {
            return .secondary
        } else if value is Bool {
            return Color(red: 0.0, green: 0.45, blue: 0.85) // 蓝色
        } else if value is NSNumber {
            return Color(red: 0.0, green: 0.45, blue: 0.85) // 蓝色
        } else if value is String {
            return Color(red: 0.75, green: 0.15, blue: 0.05) // 红色
        }
        return theme.workspaceTextColor()
    }

    private var formattedLeafValue: String {
        if value is NSNull {
            return "null"
        } else if let bool = value as? Bool {
            return bool ? "true" : "false"
        } else if let number = value as? NSNumber {
            // 区分整数和浮点数
            if CFNumberIsFloatType(number) {
                return String(Double(truncating: number))
            }
            return String(Int64(truncating: number))
        } else if let string = value as? String {
            // 长字符串截断显示
            if string.count > Self.maxInlineLength {
                let truncated = string.prefix(Self.maxInlineLength)
                return "\"\(truncated)…\""
            }
            return "\"\(string)\""
        }
        return "\(value)"
    }
}
