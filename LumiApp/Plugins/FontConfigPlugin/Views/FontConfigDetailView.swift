import AppKit
import LumiUI
import SwiftUI

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
        VStack(alignment: .leading, spacing: 8) {
            // MARK: - 标题栏
            HStack {
                Image(systemName: "textformat")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "0A84FF"))
                Text(String(localized: "Editor Font", table: "FontConfig"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(hex: "1C1C1E"))
                Spacer()
                currentFontBadge
            }

            // MARK: - 预览区
            previewSection

            GlassDivider()

            // MARK: - 搜索框
            searchField

            // MARK: - 字体列表
            fontList
        }
    }

    // MARK: - Subviews

    private var currentFontBadge: some View {
        AppTag(viewModel.displayName, systemImage: "textformat.size")
    }

    private var previewSection: some View {
        Text("abcdefghijklmnopqrstuvwxyz\nABCDEFGHIJKLMNOPQRSTUVWXYZ\n0123456789\n{}[]()<>+-=*/%!&|^~")
            .font(.custom(viewModel.selectedPostScriptName ?? "SF Mono", size: 12))
            .foregroundColor(Color(hex: "1C1C1E"))
            .lineSpacing(2)
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .appSurface(style: .subtle, cornerRadius: 8)
    }

    private var searchField: some View {
        AppSearchBar(
            text: $searchText,
            placeholder: LocalizedStringKey(String(localized: "Search fonts...", table: "FontConfig"))
        )
    }

    private var fontList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // MARK: 系统默认选项
                FontRow(
                    title: String(localized: "System Monospaced", table: "FontConfig"),
                    subtitle: "SF Mono",
                    isSelected: viewModel.selectedPostScriptName == nil,
                    previewFontName: nil
                ) {
                    viewModel.selectFont(nil)
                }

                GlassDivider()
                    .padding(.horizontal, 16)

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
                        GlassDivider()
                            .padding(.leading, 8)
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
        AppListRow(isSelected: isSelected, action: action) {
            HStack(spacing: 10) {
                // 选中指示
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 12))
                    .foregroundColor(
                        isSelected
                            ? Color(hex: "0A84FF")
                            : Color(hex: "98989E").opacity(0.4)
                    )

                // 字体信息
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(previewFontName.map { .custom($0, size: 12) } ?? .system(size: 12))
                        .foregroundColor(Color(hex: "1C1C1E"))
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 9))
                        .foregroundColor(Color(hex: "98989E"))
                        .lineLimit(1)
                }

                Spacer()
            }
        }
    }
}
