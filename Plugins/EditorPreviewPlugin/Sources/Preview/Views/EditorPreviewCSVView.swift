import LumiKernel
import LumiUI
import os
import SuperLogKit
import SwiftUI

/// CSV/TSV 文件预览视图。
///
/// 以表格形式展示数据，自动检测分隔符和表头。
public struct EditorPreviewCSVView: View, SuperLog {
    public nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.editor-inline-preview.csv-view"
    )
    public nonisolated static let emoji = "📊"
    public nonisolated static let verbose: Bool = true

    @EnvironmentObject private var themeVM: AppThemeVM

    public let csvText: String
    public let fileURL: URL?

    public var body: some View {
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

    private var parsedTable: Result<CSVPreviewParser.ParsedTable, Error> {
        Result {
            try CSVPreviewParser.parse(csvText)
        }
    }

    // MARK: - 视图

    private var emptyView: some View {
        VStack(spacing: 10) {
            Image(systemName: "tablecells")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text(LumiPluginLocalization.string("No CSV content to preview.", bundle: .module))
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
            Text(LumiPluginLocalization.string("Invalid CSV", bundle: .module))
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

    private func tableView(_ table: CSVPreviewParser.ParsedTable) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // 统计信息
            if !table.rows.isEmpty {
                Text(String(
                    format: LumiPluginLocalization.string("%d rows × %d columns", bundle: .module),
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
