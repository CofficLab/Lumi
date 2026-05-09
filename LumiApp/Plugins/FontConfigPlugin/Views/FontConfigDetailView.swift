import SwiftUI
import AppKit

/// 字体配置详情视图（Popover 内容）
///
/// 展示可用的等宽字体列表，支持搜索过滤和实时预览。
struct FontConfigDetailView: View {
    @ObservedObject var viewModel: FontConfigViewModel
    @State private var searchText: String = ""

    private var filteredFonts: [MonospacedFontItem] {
        guard !searchText.isEmpty else { return viewModel.availableFonts }
        return viewModel.availableFonts.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText) ||
            $0.postScriptName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题栏
            HStack {
                Image(systemName: "textformat")
                    .font(.system(size: 14))
                    .foregroundStyle(.blue)
                Text(String(localized: "Editor Font", table: "FontConfig"))
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                currentFontBadge
            }

            // 预览区
            previewSection

            Divider()

            // 搜索框
            searchField

            // 字体列表
            fontList
        }
    }

    // MARK: - Subviews

    private var currentFontBadge: some View {
        Text(viewModel.displayName)
            .font(.system(size: 10, weight: .medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.08))
            .cornerRadius(6)
    }

    private var previewSection: some View {
        Text("abcdefghijklmnopqrstuvwxyz\nABCDEFGHIJKLMNOPQRSTUVWXYZ\n0123456789\n{}[]()<>+-=*/%!&|^~")
            .font(.custom(viewModel.selectedPostScriptName ?? "SF Mono", size: 12))
            .lineSpacing(2)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.04))
            .cornerRadius(6)
    }

    private var searchField: some View {
        TextField(String(localized: "Search fonts...", table: "FontConfig"), text: $searchText)
            .textFieldStyle(.plain)
            .font(.system(size: 12))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.06))
            .cornerRadius(6)
    }

    private var fontList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // 系统默认选项
                FontRow(
                    title: String(localized: "System Monospaced", table: "FontConfig"),
                    subtitle: "SF Mono",
                    isSelected: viewModel.selectedPostScriptName == nil,
                    previewFontName: nil
                ) {
                    viewModel.selectFont(nil)
                }

                Divider()

                ForEach(filteredFonts) { font in
                    FontRow(
                        title: font.displayName,
                        subtitle: font.postScriptName,
                        isSelected: viewModel.selectedPostScriptName == font.postScriptName,
                        previewFontName: font.postScriptName
                    ) {
                        viewModel.selectFont(font.postScriptName)
                    }

                    if font.id != filteredFonts.last?.id {
                        Divider().padding(.leading, 12)
                    }
                }
            }
        }
        .frame(maxHeight: 240)
    }
}

// MARK: - Font Row

private struct FontRow: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    let previewFontName: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                // 选中指示
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 12))
                    .foregroundStyle(isSelected ? .blue : .secondary.opacity(0.4))

                // 字体信息
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(previewFontName.map { .custom($0, size: 12) } ?? .system(size: 12))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
