import os
import SwiftUI

/// JSON 文件预览视图。
///
/// 以可折叠树形结构展示 JSON 数据，支持 JSONL（每行一个 JSON 对象）。
struct EditorPreviewJSONView: View, SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.editor-inline-preview.json-view"
    )
    nonisolated static let emoji = "📋"
    nonisolated static let verbose: Bool = true

    @EnvironmentObject private var themeVM: AppThemeVM

    let jsonText: String

    var body: some View {
        Group {
            if jsonText.isEmpty {
                emptyView
            } else {
                switch parsedValue {
                case let .success(value):
                    jsonScrollView(value)
                case let .failure(error):
                    errorView(error)
                }
            }
        }
        .background(themeVM.activeChromeTheme.workspaceBackgroundColor())
    }

    // MARK: - 解析

    private enum ParsedValue: Equatable {
        case object([[String: Any]])
        case array([Any])
        case single(Any)

        static func == (lhs: ParsedValue, rhs: ParsedValue) -> Bool {
            switch (lhs, rhs) {
            case (.single, .single), (.array, .array), (.object, .object):
                return true
            default:
                return false
            }
        }
    }

    private var parsedValue: Result<Any, Error> {
        // 先尝试标准 JSON 解析
        let trimmed = jsonText.trimmingCharacters(in: .whitespacesAndNewlines)
        if let data = trimmed.data(using: .utf8) {
            do {
                let value = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
                return .success(value)
            } catch {
                // 如果标准解析失败，尝试 JSONL
                let jsonlResult = parseJSONL(trimmed)
                if !jsonlResult.isEmpty {
                    return .success(jsonlResult)
                }
                return .failure(error)
            }
        }
        return .failure(JSONParseError.invalidData)
    }

    private func parseJSONL(_ text: String) -> [Any] {
        var results: [Any] = []
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else { continue }
            if let value = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) {
                results.append(value)
            }
        }
        return results
    }

    private enum JSONParseError: LocalizedError {
        case invalidData

        var errorDescription: String? {
            switch self {
            case .invalidData:
                return String(localized: "Invalid JSON data", table: "EditorPreview")
            }
        }
    }

    // MARK: - 视图

    private var emptyView: some View {
        VStack(spacing: 10) {
            Image(systemName: "curlybraces")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text(String(localized: "No JSON content to preview.", table: "EditorPreview"))
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
            Text(String(localized: "Invalid JSON", table: "EditorPreview"))
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

// MARK: - JSON 树节点

private struct JSONTreeNode: View {
    let key: String?
    let value: Any
    let depth: Int
    let theme: any LumiAppChromeTheme

    @State private var isExpanded: Bool

    init(key: String?, value: Any, depth: Int, theme: any LumiAppChromeTheme) {
        self.key = key
        self.value = value
        self.depth = depth
        self.theme = theme
        // 浅层默认展开，深层默认折叠
        self._isExpanded = State(initialValue: depth < 3)
    }

    private static let maxInlineLength = 80

    var body: some View {
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
                Text(": ")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(theme.workspaceSecondaryTextColor())
            }

            // 类型标记
            let (typeName, count) = collectionInfo
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
                Text(": ")
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
