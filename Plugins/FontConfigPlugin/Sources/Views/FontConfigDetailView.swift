import AppKit
import LumiUI
import SwiftUI
import LumiKernel

/// 字体配置详情视图（Popover 内容）
///
/// 展示可用的等宽字体列表，支持搜索过滤和实时预览。
public struct FontConfigDetailView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @ObservedObject var viewModel: FontConfigViewModel
    @State private var searchText: String = ""

    private var filteredFonts: [MonospacedFontItem] {
        guard !searchText.isEmpty else { return viewModel.availableFonts }
        return viewModel.availableFonts.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText) ||
            $0.postScriptName.localizedCaseInsensitiveContains(searchText)
        }
    }

    public var body: some View {
        StatusBarPopoverScaffold(
            title: LumiPluginLocalization.string("Editor Font", bundle: .module),
            systemImage: "textformat"
        ) {
            currentFontBadge
        } content: {
            VStack(alignment: .leading, spacing: 8) {
                previewSection

                GlassDivider()

                searchField

                fontList
            }
        }
    }

    // MARK: - Subviews

    private var currentFontBadge: some View {
        AppTag(viewModel.displayName, systemImage: "textformat.size")
    }

    private var previewSection: some View {
        Text(verbatim: LumiPluginLocalization.string("abcdefghijklmnopqrstuvwxyz\nABCDEFGHIJKLMNOPQRSTUVWXYZ\n0123456789\n{}[]()<>+-=*/%!&|^~", bundle: .module))
            .font(.custom(viewModel.selectedPostScriptName ?? "SF Mono", size: 12))
            .foregroundColor(theme.textPrimary)
            .lineSpacing(2)
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .appSurface(style: .subtle, cornerRadius: 8)
    }

    private var searchField: some View {
        AppSearchBar(
            text: $searchText,
            placeholder: LocalizedStringKey(LumiPluginLocalization.string("Search fonts...", bundle: .module))
        )
    }

    private var fontList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // MARK: 系统默认选项
                FontRow(
                    title: LumiPluginLocalization.string("System Monospaced", bundle: .module),
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
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    public let title: String
    public let subtitle: String
    public let isSelected: Bool
    public let previewFontName: String?
    public let action: () -> Void

    public var body: some View {
        AppListRow(isSelected: isSelected, action: action) {
            HStack(spacing: 10) {
                // 选中指示
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.appCaption)
                    .foregroundColor(isSelected ? theme.primary : theme.textTertiary.opacity(0.4))

                // 字体信息
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(previewFontName.map { .custom($0, size: 12) } ?? .system(size: 12))
                        .foregroundColor(theme.textPrimary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.appMicro)
                        .foregroundColor(theme.textTertiary)
                        .lineLimit(1)
                }

                Spacer()
            }
        }
    }
}
