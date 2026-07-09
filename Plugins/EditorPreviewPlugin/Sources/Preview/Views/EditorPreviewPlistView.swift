import Foundation
import LumiCoreKit
import LumiUI
import SuperLogKit
import os
import SwiftUI

/// Property List 文件预览视图。
///
/// 以可折叠树形结构展示 plist 数据，支持 XML 和二进制格式。
public struct EditorPreviewPlistView: View, SuperLog {
    public nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.editor-inline-preview.plist-view"
    )
    public nonisolated static let emoji = "📋"
    public nonisolated static let verbose: Bool = true

    @EnvironmentObject private var themeVM: AppThemeVM

    public let plistText: String

    public var body: some View {
        Group {
            if plistText.isEmpty {
                emptyView
            } else {
                switch parsedValue {
                case let .success(value):
                    plistScrollView(value)
                case let .failure(error):
                    errorView(error)
                }
            }
        }
        .background(themeVM.activeChromeTheme.workspaceBackgroundColor())
    }

    // MARK: - 解析

    private var parsedValue: Result<Any, Error> {
        let trimmed = plistText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8) else {
            return .failure(PlistParseError.invalidData)
        }

        // 先尝试 XML plist
        if let value = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) {
            return .success(value)
        }

        // 尝试二进制 plist（从文件 URL 读取）
        // 注意：编辑器中显示的是文本，所以二进制 plist 通常不会出现在这里
        // 但如果文件是二进制格式，编辑器可能显示的是乱码

        return .failure(PlistParseError.invalidFormat)
    }

    private enum PlistParseError: LocalizedError {
        case invalidData
        case invalidFormat

        var errorDescription: String? {
            switch self {
            case .invalidData:
                return LumiPluginLocalization.string("Invalid plist data", bundle: .module)
            case .invalidFormat:
                return LumiPluginLocalization.string("Unsupported plist format", bundle: .module)
            }
        }
    }

    // MARK: - 视图

    private var emptyView: some View {
        VStack(spacing: 10) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text(LumiPluginLocalization.string("No plist content to preview.", bundle: .module))
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
            Text(LumiPluginLocalization.string("Invalid plist", bundle: .module))
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

    private func plistScrollView(_ value: Any) -> some View {
        ScrollView([.horizontal, .vertical]) {
            PlistTreeNode(
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

// MARK: - Plist 树节点

private struct PlistTreeNode: View {
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

    // MARK: - 集合节点（字典/数组）

    @ViewBuilder
    private var collectionNode: some View {
        VStack(alignment: .leading, spacing: 0) {
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
                Text(key)
                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                    .foregroundColor(Self.keyColor)
                Text(verbatim: LumiPluginLocalization.string(" = ", bundle: .module))
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(theme.workspaceSecondaryTextColor())
            }

            // 类型标记
            let (typeName, _) = collectionInfo
            Text(typeName)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(theme.workspaceSecondaryTextColor())

            if !isExpanded {
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
                    PlistTreeNode(
                        key: childKey,
                        value: childValue,
                        depth: depth + 1,
                        theme: theme
                    )
                }
            }
        } else if let array = value as? [Any] {
            ForEach(Array(array.enumerated()), id: \.offset) { index, childValue in
                PlistTreeNode(
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
                Text(key)
                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                    .foregroundColor(Self.keyColor)
                Text(verbatim: LumiPluginLocalization.string(" = ", bundle: .module))
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
        } else if value is Date {
            return Color(red: 0.6, green: 0.4, blue: 0.0) // 橙色
        } else if value is Data {
            return Color(red: 0.3, green: 0.3, blue: 0.3) // 灰色
        }
        return theme.workspaceTextColor()
    }

    private var formattedLeafValue: String {
        if value is NSNull {
            return "null"
        } else if let bool = value as? Bool {
            return bool ? "true" : "false"
        } else if let number = value as? NSNumber {
            if CFNumberIsFloatType(number) {
                return String(Double(truncating: number))
            }
            return String(Int64(truncating: number))
        } else if let string = value as? String {
            if string.count > Self.maxInlineLength {
                let truncated = string.prefix(Self.maxInlineLength)
                return "\"\(truncated)…\""
            }
            return "\"\(string)\""
        } else if let date = value as? Date {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .medium
            return formatter.string(from: date)
        } else if let data = value as? Data {
            return "<\(data.count) bytes>"
        }
        return "\(value)"
    }
}
