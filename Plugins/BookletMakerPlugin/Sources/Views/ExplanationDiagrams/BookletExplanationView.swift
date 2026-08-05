import SwiftUI

// MARK: - Booklet Explanation View

/// 示意图区域，展示 PDF 转换前后的效果
///
/// - 上方：8 页示例 PDF（每页内容不同，组合起来是一个完整的故事）
/// - 下方：顶部为「装订前 / 装订后」tab
///   - 装订前：左侧张数 tab，右侧显示该张纸的实际拼版内容
///   - 装订后：可交互翻页的虚拟小册子
struct BookletExplanationView: View {
    let settings: BookletSettings

    /// 下方区域当前选中的 tab
    @State private var selectedTab: ExplanationTab = .beforeBinding

    private enum ExplanationTab {
        case beforeBinding
        case afterBinding
    }

    var body: some View {
        GeometryReader { geo in
            // 上下空间分配：上方页面条约占 40%，下方 tab 内容约占 60%
            let stripHeight = max(90, min(150, geo.size.height * 0.36))

            VStack(spacing: 12) {
                // 上方：8 页原始 PDF
                inputStrip(pageHeight: stripHeight)

                // 转换箭头
                Image(systemName: "arrow.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.accentColor)

                // 下方：装订前 / 装订后 tab
                VStack(spacing: 8) {
                    tabPicker

                    tabContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    // MARK: - Input Strip

    /// 8 页示例故事，横向并排展示；横向空间不足时支持滚动
    private func inputStrip(pageHeight: CGFloat) -> some View {
        VStack(spacing: 4) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(SampleStory.pages) { page in
                        StoryPageView(pageNumber: page.id, height: pageHeight)
                    }
                }
                .padding(.horizontal, 2)
                // 内容整体居中：空间足够时不偏左
                .frame(maxWidth: .infinity)
            }

            Text(BookletLocalization.string("Original PDF · 8 pages"))
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Bottom Tabs

    private var tabPicker: some View {
        Picker("", selection: $selectedTab) {
            Text(BookletLocalization.string("Before Binding"))
                .tag(ExplanationTab.beforeBinding)
            Text(BookletLocalization.string("After Binding"))
                .tag(ExplanationTab.afterBinding)
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 240)
        .labelsHidden()
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .beforeBinding:
            SheetPreviewView(settings: settings)
        case .afterBinding:
            FlipBookView()
        }
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
