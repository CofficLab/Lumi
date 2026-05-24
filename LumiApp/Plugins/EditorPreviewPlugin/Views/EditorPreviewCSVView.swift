import os
import SwiftUI

/// CSV/TSV 文件预览视图。
///
/// 以表格形式展示数据，自动检测分隔符和表头。
struct EditorPreviewCSVView: View, SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.editor-inline-preview.csv-view"
    )
    nonisolated static let emoji = "📊"
    nonisolated static let verbose: Bool = true

    @EnvironmentObject private var themeVM: AppThemeVM

    let csvText: String
    let fileURL: URL?

    var body: some View {
        Group {
            if csvText.isEmpty {
                emptyView
            } else {
                switch parsedTable {
                case let .success(table):
                    tableView(table)
                case let .failure(error):
                    errorView(error)
                }
            }
        }
        .background(themeVM.activeChromeTheme.workspaceBackgroundColor())
    }

    // MARK: - 解析

    private struct ParsedTable {
        let headers: [String]
        let rows: [[String]]
    }

    private var parsedTable: Result<ParsedTable, Error> {
        Result {
            let trimmed = csvText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                throw CSVParseError.emptyData
            }

            // 自动检测分隔符
            let separator = detectSeparator(trimmed)
            let lines = parseLines(trimmed, separator: separator)
            guard !lines.isEmpty else {
                throw CSVParseError.noData
            }

            let headers = lines[0]
            let rows = Array(lines.dropFirst())
            return ParsedTable(headers: headers, rows: rows)
        }
    }

    private func detectSeparator(_ text: String) -> Character {
        let firstLine = text.components(separatedBy: .newlines).first ?? text
        let commaCount = firstLine.filter { $0 == "," }.count
        let tabCount = firstLine.filter { $0 == "\t" }.count
        let semicolonCount = firstLine.filter { $0 == ";" }.count

        if tabCount > commaCount && tabCount > semicolonCount {
            return "\t"
        } else if semicolonCount > commaCount {
            return ";"
        }
        return ","
    }

    private func parseLines(_ text: String, separator: Character) -> [[String]] {
        var result: [[String]] = []
        var currentLine: [String] = []
        var currentField = ""
        var inQuotes = false

        let chars = Array(text)
        var index = 0

        while index < chars.count {
            let char = chars[index]

            if inQuotes {
                if char == "\"" {
                    if index + 1 < chars.count && chars[index + 1] == "\"" {
                        currentField.append("\"")
                        index += 1
                    } else {
                        inQuotes = false
                    }
                } else {
                    currentField.append(char)
                }
            } else {
                if char == "\"" {
                    inQuotes = true
                } else if char == separator {
                    currentLine.append(currentField.trimmingCharacters(in: .whitespaces))
                    currentField = ""
                } else if char == "\n" {
                    currentLine.append(currentField.trimmingCharacters(in: .whitespaces))
                    if !currentLine.isEmpty && !(currentLine.count == 1 && currentLine[0].isEmpty) {
                        result.append(currentLine)
                    }
                    currentLine = []
                    currentField = ""
                } else if char == "\r" {
                    // 跳过 \r
                } else {
                    currentField.append(char)
                }
            }
            index += 1
        }

        // 处理最后一行
        if !currentField.isEmpty || !currentLine.isEmpty {
            currentLine.append(currentField.trimmingCharacters(in: .whitespaces))
            if !currentLine.isEmpty && !(currentLine.count == 1 && currentLine[0].isEmpty) {
                result.append(currentLine)
            }
        }

        return result
    }

    private enum CSVParseError: LocalizedError {
        case emptyData
        case noData

        var errorDescription: String? {
            switch self {
            case .emptyData:
                return String(localized: "Empty CSV data", table: "EditorPreview")
            case .noData:
                return String(localized: "No data rows found", table: "EditorPreview")
            }
        }
    }

    // MARK: - 视图

    private var emptyView: some View {
        VStack(spacing: 10) {
            Image(systemName: "tablecells")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text(String(localized: "No CSV content to preview.", table: "EditorPreview"))
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
            Text(String(localized: "Invalid CSV", table: "EditorPreview"))
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

    private func tableView(_ table: ParsedTable) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // 统计信息
            if !table.rows.isEmpty {
                Text(String(
                    format: String(localized: "%d rows × %d columns", table: "EditorPreview"),
                    table.rows.count,
                    table.headers.count
                ))
                .font(.caption)
                .foregroundStyle(themeVM.activeChromeTheme.workspaceSecondaryTextColor())
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                Divider()
            }

            // 表格
            ScrollView([.horizontal, .vertical]) {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    Section {
                        ForEach(Array(table.rows.enumerated()), id: \.offset) { rowIndex, row in
                            tableRow(row: row, isHeader: false, rowIndex: rowIndex)
                        }
                    } header: {
                        tableRow(row: table.headers, isHeader: true, rowIndex: -1)
                    }
                }
            }
        }
    }

    private func tableRow(row: [String], isHeader: Bool, rowIndex: Int) -> some View {
        HStack(spacing: 0) {
            // 行号
            if !isHeader {
                Text("\(rowIndex + 1)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(themeVM.activeChromeTheme.workspaceSecondaryTextColor())
                    .frame(width: 40, alignment: .trailing)
                    .padding(.trailing, 8)
                    .padding(.vertical, 8)
                    .padding(.leading, 12)
                    Divider()
            } else {
                Color.clear.frame(width: 40, height: 1)
            }

            ForEach(0..<row.count, id: \.self) { colIndex in
                Text(row[colIndex])
                    .font(.system(size: isHeader ? 13 : 13, weight: isHeader ? .semibold : .regular))
                    .foregroundStyle(isHeader
                        ? themeVM.activeChromeTheme.workspaceTextColor()
                        : themeVM.activeChromeTheme.workspaceTextColor()
                    )
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(minWidth: 80, maxWidth: 200, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, isHeader ? 8 : 6)
                    .overlay(alignment: .trailing) {
                        if colIndex < row.count - 1 {
                            Divider()
                        }
                    }
                    .background(isHeader
                        ? themeVM.activeChromeTheme.workspaceSecondaryTextColor().opacity(0.08)
                        : Color.clear
                    )
            }
        }
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}
