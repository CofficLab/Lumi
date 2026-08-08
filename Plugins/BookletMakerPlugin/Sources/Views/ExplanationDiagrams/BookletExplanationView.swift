import SwiftUI

// MARK: - Booklet Explanation View

/// 原理示意图区域，展示 PDF 转换前后的效果。
///
/// 采用左右布局：
/// - 左侧上方：「装订前 / 装订后」tab
/// - 左侧下方：张数 tab（第一张 … 第四张）
/// - 右侧：根据 tab 选择显示装订前的纸张拼版预览，或装订后的翻页小册子
/// - 顶部：8 页原始 PDF 示例，带转换箭头
struct BookletExplanationView: View {
    let settings: BookletSettings

    /// 当前选中的 tab：装订前 / 装订后
    @State private var selectedBindingTab: BindingTab = .beforeBinding

    /// 当前选中的纸张（装订前模式，0-based）
    @State private var selectedSheet: Int = 0

    private enum BindingTab {
        case beforeBinding
        case afterBinding
    }

    var body: some View {
        GeometryReader { geo in
            let inputStripHeight = max(90, min(150, geo.size.height * 0.36))

            VStack(spacing: 0) {
                // 顶部：8 页原始 PDF
                inputStrip(pageHeight: inputStripHeight)

                // 转换箭头
                Image(systemName: "arrow.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.accentColor)
                    .frame(height: 20)

                // 下方主体：左右布局
                HStack(spacing: 0) {
                    // 左侧：装订前/装订后 tab + 张数 tab
                    leftControlPanel
                        .frame(width: max(80, min(120, geo.size.width * 0.2)))

                    // 分隔线
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: 1)

                    // 右侧：预览内容
                    rightContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .onChange(of: settings) { _, _ in
            selectedSheet = 0
        }
    }

    // MARK: - Input Strip

    /// 8 页示例故事，横向并排展示
    private func inputStrip(pageHeight: CGFloat) -> some View {
        VStack(spacing: 4) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(SampleStory.pages) { page in
                        StoryPageView(pageNumber: page.id, height: pageHeight)
                    }
                }
                .padding(.horizontal, 2)
                .frame(maxWidth: .infinity)
            }

            Text(BookletLocalization.string("Original PDF · 8 pages"))
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Left Control Panel

    private var leftControlPanel: some View {
        VStack(spacing: 0) {
            // 上方：装订前 / 装订后 tab
            bindingTabPicker
                .padding(.horizontal, 8)
                .padding(.top, 12)
                .padding(.bottom, 16)

            // 分隔线
            Rectangle()
                .fill(Color.secondary.opacity(0.15))
                .frame(height: 1)

            // 下方：张数 tab
            sheetTabList
                .frame(maxHeight: .infinity)
        }
    }

    /// 装订前 / 装订后 Picker
    private var bindingTabPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(BookletLocalization.string("Mode"))
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)

            Picker("", selection: $selectedBindingTab) {
                Text(BookletLocalization.string("Before"))
                    .tag(BindingTab.beforeBinding)
                Text(BookletLocalization.string("After"))
                    .tag(BindingTab.afterBinding)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
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
        case .beforeBinding:
            beforeBindingContent
        case .afterBinding:
            afterBindingContent
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
