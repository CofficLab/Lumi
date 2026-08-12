import SwiftUI
import AppKit

// MARK: - Booklet Explanation View

/// 原理示意图区域，展示 PDF 转换前后的效果。
///
/// 采用左右布局：
/// - 左侧：阶段 tab（原始 PDF / 转换后 / 装订前 / 装订后）+ 当前阶段摘要/纸张列表
/// - 右侧：根据选中 tab 显示对应预览：原始 PDF 展示输入页面、转换后
///   展示 4 张 A4 输出 PDF 全貌、装订前展示单张拼版细节、装订后展示翻页小册子
struct BookletExplanationView: View {
    let document: CurrentPDFDocument
    let settings: BookletSettings

    /// 当前选中的 tab：原始 PDF / 转换后 / 装订前 / 装订后
    @State private var selectedBindingTab: BindingTab = .original

    /// 当前选中的物理纸张（装订前模式，0-based）
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
                // 左侧：阶段 tab + 当前阶段的摘要/纸张列表
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
        .onChange(of: document.id) { _, _ in
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

            // 下方：原始/转换摘要，或装订前的纸张 tab
            leftDetailPanel
                .frame(maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private var leftDetailPanel: some View {
        switch selectedBindingTab {
        case .original:
            stageSummary(
                BookletLocalization.string(
                    "%@ · %lld pages",
                    settings.outputPaper.displayName,
                    Int64(document.pageCount)
                )
            )
        case .afterConversion:
            let outputSides = BookletLayoutEngine.buildOutputSides(
                inputPageCount: document.pageCount,
                settings: settings
            )
            let physicalSheets = BookletLayoutEngine.buildPhysicalSheets(
                inputPageCount: document.pageCount,
                settings: settings
            )
            stageSummary(
                BookletLocalization.string(
                    "%lld pages → %lld %@ sheets · %lld print sides",
                    Int64(document.pageCount),
                    Int64(physicalSheets.count),
                    settings.outputPaper.displayName,
                    Int64(outputSides.count)
                )
            )
        case .beforeBinding:
            sheetTabList
        case .afterBinding:
            stageSummary(
                BookletLocalization.string(
                    "After binding, it becomes a booklet with content on both sides. Each page is about half the size of an A4 sheet."
                )
            )
        }
    }

    private func stageSummary(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(text)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
        let sheets = BookletLayoutEngine.buildPhysicalSheets(
            inputPageCount: document.pageCount,
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
                        sheetTabButton(index: index, physicalSheet: sheet)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 12)
            }
        }
        .opacity(selectedBindingTab == .beforeBinding ? 1 : 0.4)
        .disabled(selectedBindingTab != .beforeBinding)
    }

    private func sheetTabButton(index: Int, physicalSheet: PhysicalSheet) -> some View {
        let isSelected = selectedSheet == index

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedSheet = index
            }
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(BookletLocalization.string("Sheet %lld", Int64(index + 1)))
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))

                Text(physicalSheetPageCaption(physicalSheet))
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

    /// 原始 PDF 预览：垂直滚动逐行展示拼版前的所有输入页面。
    ///
    /// 每页按行宽填充（最大 480pt 封顶），保持 A4 竖版比例；
    /// 超过封顶宽度时居中显示，避免极端宽视图下单页过高。
    private var originalContent: some View {
        GeometryReader { geo in
            let pageWidth = min(geo.size.width, 480)
            let pageHeight = pageWidth / document.pageAspectRatio

            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(0..<document.pageCount, id: \.self) { index in
                        PDFDocumentPageView(
                            documentURL: document.url,
                            pageNumber: index + 1
                        )
                            .frame(width: pageWidth, height: pageHeight)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    /// 转换后预览：垂直滚动逐行展示拼版产出的全部 A4 输出 PDF 缩略图。
    ///
    /// 每张缩略图与原始 8 页 PDF 尺寸一致（高 > 宽的 A4 竖版），内部
    /// 旋转 90° 装下横向拼版内容；下方带张数标签方便对照。
    private var afterConversionContent: some View {
        let outputSides = BookletLayoutEngine.buildOutputSides(
            inputPageCount: document.pageCount,
            settings: settings
        )
        return GeometryReader { geo in
            let pageWidth = min(geo.size.width, 480)
            let pageHeight = pageWidth * 1.414

            if outputSides.isEmpty {
                Color.clear
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(outputSides, id: \.index) { outputSide in
                            convertedSheetCell(
                                outputSide: outputSide,
                                pageWidth: pageWidth,
                                pageHeight: pageHeight
                            )
                            .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    /// 单个转换后 PDF 缩略图：纵向 A4 纸张预览 + 张数标签。
    ///
    /// 外层尺寸与「原始 PDF」完全一致。旋转前先显式交换内容的宽高，
    /// 因为 `rotationEffect` 只改变绘制，不会交换 SwiftUI 的布局尺寸。
    private func convertedSheetCell(outputSide: OutputSheet,
                                    pageWidth: CGFloat,
                                    pageHeight: CGFloat) -> some View {
        VStack(spacing: 4) {
            Color.clear
                .frame(width: pageWidth, height: pageHeight)
                .overlay(
                    OutputSheetView(
                        sheet: outputSide,
                        document: document,
                        settings: settings
                    )
                        .frame(width: pageHeight, height: pageWidth)
                        .rotationEffect(.degrees(90))
                )
                .clipShape(RoundedRectangle(cornerRadius: 4))

            Text(BookletLocalization.string(
                "Sheet %lld · %@",
                Int64(outputSide.physicalSheetIndex + 1),
                sideDisplayName(outputSide.side)
            ))
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.secondary)
        }
    }

    private var beforeBindingContent: some View {
        let sheets = BookletLayoutEngine.buildPhysicalSheets(
            inputPageCount: document.pageCount,
            settings: settings
        )

        return VStack(spacing: 6) {
            if sheets.indices.contains(selectedSheet) {
                physicalSheetView(sheets[selectedSheet])
            } else {
                Color.clear
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private var afterBindingContent: some View {
        FlipBookView(document: document)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
    }

    private func pairCaption(_ sheet: OutputSheet) -> String {
        BookletLocalization.string("Pages %lld + %lld",
                                   Int64(sheet.leftPage),
                                   Int64(sheet.rightPage))
    }

    private func physicalSheetPageCaption(_ sheet: PhysicalSheet) -> String {
        sheet.outputSides
            .flatMap { [$0.leftPage, $0.rightPage] }
            .map { $0 == 0 ? "–" : String($0) }
            .joined(separator: ",")
    }

    @ViewBuilder
    private func physicalSheetView(_ sheet: PhysicalSheet) -> some View {
        VStack(spacing: 10) {
            outputSideView(sheet.front)
            if let back = sheet.back {
                outputSideView(back)
            }
        }
    }

    private func outputSideView(_ outputSide: OutputSheet) -> some View {
        VStack(spacing: 3) {
            Text(sideDisplayName(outputSide.side))
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)

            OutputSheetView(
                sheet: outputSide,
                document: document,
                settings: settings
            )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Text(pairCaption(outputSide))
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
    }

    private func sideDisplayName(_ side: OutputSheet.Side) -> String {
        switch side {
        case .front:
            return BookletLocalization.string("Front")
        case .back:
            return BookletLocalization.string("Back")
        }
    }
}
