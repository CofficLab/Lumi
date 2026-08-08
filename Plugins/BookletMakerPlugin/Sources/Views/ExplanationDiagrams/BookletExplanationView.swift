import SwiftUI
import AppKit

// MARK: - Booklet Explanation View

/// 原理示意图区域，展示 PDF 转换前后的效果。
///
/// 采用左右布局：
/// - 左侧：阶段 tab（原始 PDF / 转换后 / 装订前 / 装订后）+ 装订前阶段的张数 tab
/// - 右侧：根据选中 tab 显示对应预览：原始 PDF 展示输入页面、转换后
///   展示 4 张 A4 输出 PDF 全貌、装订前展示单张拼版细节、装订后展示翻页小册子
struct BookletExplanationView: View {
    let settings: BookletSettings

    /// 当前选中的 tab：原始 PDF / 转换后 / 装订前 / 装订后
    @State private var selectedBindingTab: BindingTab = .original

    /// 当前选中的纸张（装订前模式，0-based）
    @State private var selectedSheet: Int = 0

    private enum BindingTab {
        /// 原始 PDF：展示拼版前的 8 页输入页面。
        case original
        /// 转换后：展示拼版产出的 4 张 A4 输出 PDF。
        case afterConversion
        case beforeBinding
        case afterBinding
    }

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                // 左侧：阶段 tab + 装订前阶段的张数 tab
                leftControlPanel
                    .frame(width: max(96, min(140, geo.size.width * 0.22)))

                // 分隔线
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 1)
                    .padding()

                // 右侧：选中 tab 的预览内容
                rightContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .onChange(of: settings) { _, _ in
            selectedSheet = 0
        }
    }

    // MARK: - Left Control Panel

    private var leftControlPanel: some View {
        VStack(spacing: 0) {
            // 上方：阶段 tab
            bindingTabPicker
                .padding(.horizontal, 8)
                .padding(.top, 12)
                .padding(.bottom, 16)

            // 分隔线
            Rectangle()
                .fill(Color.secondary.opacity(0.15))
                .frame(height: 1)

            // 下方：装订前阶段的张数 tab
            sheetTabList
                .frame(maxHeight: .infinity)
        }
    }

    /// 阶段 Picker（上下布局）：原始 PDF → 转换后 → 装订前 → 装订后。
    private var bindingTabPicker: some View {
        VStack(spacing: 6) {
            bindingTabButton(
                title: BookletLocalization.string("Original"),
                tab: .original
            )
            bindingTabButton(
                title: BookletLocalization.string("Converted"),
                tab: .afterConversion
            )
            bindingTabButton(
                title: BookletLocalization.string("Before"),
                tab: .beforeBinding
            )
            bindingTabButton(
                title: BookletLocalization.string("After"),
                tab: .afterBinding
            )
        }
    }

    private func bindingTabButton(title: String, tab: BindingTab) -> some View {
        let isSelected = selectedBindingTab == tab
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedBindingTab = tab
            }
        } label: {
            Text(title)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected
                            ? Color.accentColor.opacity(0.15)
                            : Color.secondary.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .foregroundColor(isSelected ? .accentColor : .primary)
    }

    /// 张数 tab 列表（装订前模式时高亮显示）
    private var sheetTabList: some View {
        let sheets = BookletLayoutEngine.buildSheets(
            inputPageCount: SampleStory.pageCount,
            settings: settings
        )

        return VStack(alignment: .leading, spacing: 0) {
            Text(BookletLocalization.string("Sheet"))
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 8)

            ScrollView {
                VStack(spacing: 4) {
                    ForEach(Array(sheets.enumerated()), id: \.element.index) { index, sheet in
                        sheetTabButton(index: index, sheet: sheet)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 12)
            }
        }
        .opacity(selectedBindingTab == .beforeBinding ? 1 : 0.4)
        .disabled(selectedBindingTab != .beforeBinding)
    }

    private func sheetTabButton(index: Int, sheet: OutputSheet) -> some View {
        let isSelected = selectedSheet == index

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedSheet = index
            }
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(BookletLocalization.string("Sheet %lld", Int64(index + 1)))
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))

                Text("\(sheet.leftPage),\(sheet.rightPage)")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected
                        ? Color.accentColor.opacity(0.15)
                        : Color.secondary.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .foregroundColor(isSelected ? .accentColor : .primary)
    }

    // MARK: - Right Content

    @ViewBuilder
    private var rightContent: some View {
        switch selectedBindingTab {
        case .original:
            originalContent
        case .afterConversion:
            afterConversionContent
        case .beforeBinding:
            beforeBindingContent
        case .afterBinding:
            afterBindingContent
        }
    }

    /// 原始 PDF 预览：横向滚动展示拼版前的所有输入页面。
    ///
    /// 视觉与之前的「顶部输入条」一致，但搬到右侧详情区域，
    /// 配合左侧「原始 PDF」tab 形成完整阶段。
    private var originalContent: some View {
        VStack(spacing: 8) {
            Text(BookletLocalization.string(
                "%@ · %lld pages",
                settings.outputPaper.displayName,
                Int64(SampleStory.pageCount)
            ))
            .font(.system(size: 10))
            .foregroundColor(.secondary)

            // 按可用高度自适应：尽量填满竖向空间。
            GeometryReader { geo in
                let pageHeight = max(180, geo.size.height - 8)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(SampleStory.pages) { page in
                            StoryPageView(pageNumber: page.id, height: pageHeight)
                        }
                    }
                    .padding(.horizontal, 2)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    /// 转换后预览：以 2×2 网格展示拼版产出的全部 A4 输出 PDF 缩略图。
    ///
    /// 每张缩略图与原始 8 页 PDF 尺寸一致（高 > 宽的 A4 竖版），内部
    /// 上下堆叠拼版后的两张源页；下方带张数标签方便对照。
    private var afterConversionContent: some View {
        let sheets = BookletLayoutEngine.buildSheets(
            inputPageCount: SampleStory.pageCount,
            settings: settings
        )

        return VStack(spacing: 8) {
            Text(BookletLocalization.string(
                "%lld pages → %lld %@ sheets",
                Int64(SampleStory.pageCount),
                Int64(sheets.count),
                settings.outputPaper.displayName
            ))
            .font(.system(size: 10))
            .foregroundColor(.secondary)

            if sheets.isEmpty {
                Color.clear
            } else {
                let columns = [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10)
                ]
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(sheets, id: \.index) { sheet in
                            convertedSheetCell(sheet: sheet)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    /// 单个转换后 PDF 缩略图：纵向 A4 纸张预览 + 张数标签。
    ///
    /// 内容与「装订前」完全一致（即同一份 `OutputSheetView`），
    /// 整体顺时针旋转 90°，让卡片呈「高 > 宽」的竖版形态，
    /// 与顶部输入条的视觉风格保持一致。
    private func convertedSheetCell(sheet: OutputSheet) -> some View {
        VStack(spacing: 4) {
            // 纵向 A4 比例的外框，内部旋转 90° 装下横向的拼版内容
            Color.clear
                .aspectRatio(1.0 / 1.414, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .overlay(
                    OutputSheetView(sheet: sheet, settings: settings)
                        .rotationEffect(.degrees(90))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                )
                .clipShape(RoundedRectangle(cornerRadius: 4))

            Text(BookletLocalization.string("Sheet %lld", Int64(sheet.index + 1)))
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.secondary)
        }
    }

    private var beforeBindingContent: some View {
        let sheets = BookletLayoutEngine.buildSheets(
            inputPageCount: SampleStory.pageCount,
            settings: settings
        )

        return VStack(spacing: 6) {
            if sheets.indices.contains(selectedSheet) {
                let sheet = sheets[selectedSheet]

                OutputSheetView(sheet: sheet, settings: settings)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                Text(pairCaption(sheet))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            } else {
                Color.clear
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private var afterBindingContent: some View {
        FlipBookView()
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
    }

    private func pairCaption(_ sheet: OutputSheet) -> String {
        BookletLocalization.string("Pages %lld + %lld",
                                   Int64(sheet.leftPage),
                                   Int64(sheet.rightPage))
    }
}

// MARK: - Preview

#Preview("Default Settings") {
    BookletExplanationView(settings: BookletSettings())
        .frame(width: 600, height: 480)
        .padding()
}

#Preview("Simple Pair") {
    BookletExplanationView(settings: BookletSettings(
        outputPaper: .a5,
        layout: .simplePair,
        marginMM: 15,
        gutterMM: 10
    ))
    .frame(width: 600, height: 480)
    .padding()
}
