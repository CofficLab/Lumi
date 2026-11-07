#if os(iOS)
import BookletMakerCore
import SwiftUI

/// Six-step booklet flow. The two introductory steps live before PDF import;
/// this view owns the print preview, settings, review, and export steps.
struct BookletPreviewStageView: View {
    @ObservedObject var viewModel: BookletMakerViewModel
    let onExport: () -> Void
    let onShare: () -> Void
    let onSave: () -> Void
    let onReturnToGuide: (() -> Void)?
    let onFinish: () -> Void

    @State private var currentStage: BookletStage = .printLayout
    @State private var selectedOutputSides: [Int: OutputSheet.Side] = [:]
    @State private var reviewSpreadIndex = 0

    private let lastPageShortcutMinimumCount = 20
    private let firstPageShortcutMinimumPage = 20

    private var reviewPageCount: Int {
        max(viewModel.currentDocument.pageCount, 0)
    }

    private var reviewSpreadCount: Int {
        max(1, 1 + reviewPageCount / 2)
    }

    private var reviewLastSpreadIndex: Int {
        max(reviewSpreadCount - 1, 0)
    }

    private var reviewCurrentPage: Int {
        guard reviewPageCount > 0 else { return 0 }
        let firstVisiblePage = reviewSpreadIndex == 0 ? 1 : reviewSpreadIndex * 2
        return min(firstVisiblePage, reviewPageCount)
    }

    private var showsJumpToLastPage: Bool {
        reviewPageCount > lastPageShortcutMinimumCount
            && reviewSpreadIndex < reviewLastSpreadIndex
    }

    private var showsJumpToFirstPage: Bool {
        reviewCurrentPage >= firstPageShortcutMinimumPage && reviewSpreadIndex > 0
    }

    private var physicalSheets: [PhysicalSheet] {
        BookletLayoutEngine.buildPhysicalSheets(
            inputPageCount: viewModel.currentDocument.pageCount,
            settings: viewModel.settings
        )
    }

    private var a4LandscapeAspectRatio: CGFloat {
        CGFloat(PaperSize.a4.heightMM / PaperSize.a4.widthMM)
    }

    var body: some View {
        VStack(spacing: 0) {
            stageIndicator
            Divider()
            stageContent
            Divider()
            footer
        }
        .background(BookletMobileStyle.canvas)
        .onChange(of: viewModel.currentDocument.id) { _ in
            selectedOutputSides = [:]
            reviewSpreadIndex = 0
        }
        .onChange(of: viewModel.currentDocument.pageCount) { _ in
            reviewSpreadIndex = min(reviewSpreadIndex, reviewLastSpreadIndex)
        }
    }

    @ViewBuilder
    private var stageContent: some View {
        switch currentStage {
        case .printLayout:
            printLayoutContent
        case .paperSelection, .cuttingMarks:
            BookletParameterPanelView(viewModel: viewModel)
        case .bindingEffect, .review:
            reviewContent
        case .export:
            exportContent
        }
    }

    private var prototypeStep: Int {
        switch currentStage {
        case .printLayout: 3
        case .paperSelection, .cuttingMarks: 4
        case .bindingEffect, .review: 5
        case .export: 6
        }
    }

    private var stageTitle: String {
        switch currentStage {
        case .printLayout: BookletLocalization.string("Print Layout")
        case .paperSelection, .cuttingMarks: BookletLocalization.string("Paper and Layout")
        case .bindingEffect, .review: BookletLocalization.string("Review")
        case .export: BookletLocalization.string("Export")
        }
    }

    private var stageIndicator: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(stageTitle)
                    .font(.subheadline.weight(.semibold))
                    .accessibilityIdentifier("booklet.stageTitle")
                Spacer()
                Text(BookletLocalization.string("%lld/6", Int64(prototypeStep)))
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 4) {
                ForEach(1...6, id: \.self) { step in
                    Capsule()
                        .fill(step <= prototypeStep
                              ? BookletMobileStyle.accent
                              : BookletMobileStyle.accent.opacity(0.16))
                        .frame(height: 4)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: 680)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Step 3: print layout

    private var printLayoutContent: some View {
        GeometryReader { geometry in
            let contentWidth = min(geometry.size.width, 680)
            let horizontalInset: CGFloat = 16 + 10
            let paperWidth = max(contentWidth - horizontalInset * 2, 0)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    paperPickerCard
                    // 用 VStack 而不是 LazyVStack：打印面数量是页数的四分之一
                    // （8 页 → 2 张纸 → 2 个面），规模有限；而 LazyVStack 只
                    // 构造进入视口的项，屏幕外的打印面根本不在可访问性树里，
                    // 读屏用户和 UI 测试都拿不到它们。
                    VStack(spacing: 6) {
                        ForEach(physicalSheets, id: \.index) { physicalSheet in
                            physicalSheetCard(physicalSheet, paperWidth: paperWidth)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 12)
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var paperPickerCard: some View {
        HStack {
            Label(BookletLocalization.string("Paper"), systemImage: "rectangle.portrait.on.rectangle.portrait")
            Spacer()
            Picker(BookletLocalization.string("Paper"), selection: $viewModel.settings.outputPaper) {
                ForEach(PaperSize.allCases) { paper in
                    Text(paper.displayName).tag(paper)
                }
            }
            .pickerStyle(.menu)
            .tint(BookletMobileStyle.accent)
        }
        .font(.body)
        .padding(12)
        .background(BookletMobileStyle.card, in: RoundedRectangle(cornerRadius: 12))
    }

    private func physicalSheetCard(_ physicalSheet: PhysicalSheet, paperWidth: CGFloat) -> some View {
        let side = selectedOutputSides[physicalSheet.index] ?? .front
        let outputSide = side == .back ? (physicalSheet.back ?? physicalSheet.front) : physicalSheet.front
        let paperHeight = paperWidth / a4LandscapeAspectRatio

        return VStack(spacing: 6) {
            HStack {
                if physicalSheet.back != nil {
                    HStack(spacing: 2) {
                        outputSideButton(.front, selected: side == .front, sheet: physicalSheet)
                        outputSideButton(.back, selected: side == .back, sheet: physicalSheet)
                    }
                    .padding(2)
                    .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                } else {
                    Text(BookletLocalization.string("Front"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BookletMobileStyle.accent)
                }
                Spacer()
                Text(pairCaption(outputSide))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            OutputSheetView(
                sheet: outputSide,
                document: viewModel.currentDocument,
                settings: viewModel.settings
            )
            .frame(width: paperWidth, height: paperHeight)
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(BookletLocalization.string(
                "Print side %lld: pages %lld and %lld",
                Int64(outputSide.index + 1), Int64(outputSide.leftPage), Int64(outputSide.rightPage)
            ))
            // 稳定锚点：打印面的序号就是拼版引擎的输出顺序，UI 测试据此
            // 逐面核对页码配对。按钮上的锚点只覆盖「当前这一张纸」，
            // 换到背面后就换了内容，因此面序要另开一个锚点。
            .accessibilityIdentifier("booklet.printSide.\(outputSide.index)")
        }
        .padding(.horizontal, 10)
        .padding(.top, 6)
        .padding(.bottom, 8)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }

    private func outputSideButton(_ side: OutputSheet.Side,
                                 selected: Bool,
                                 sheet: PhysicalSheet) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.16)) {
                selectedOutputSides[sheet.index] = side
            }
        } label: {
            Text(side == .front
                 ? BookletLocalization.string("Front")
                 : BookletLocalization.string("Back"))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(selected ? Color.white : Color.secondary)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background {
                    if selected {
                        RoundedRectangle(cornerRadius: 6).fill(BookletMobileStyle.accent)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        // 稳定锚点：UI 测试据此验证「每张纸的正反面都能切换」——
        // 双面打印的背面此前被静默砍掉，只剩正面可看。
        .accessibilityIdentifier("booklet.side.\(sheet.index).\(side.rawValue)")
        // 标签带上这一面的页码：只说「正面 / 背面」的话，读屏用户切到
        // 背面也不知道那一面印的是哪两页。
        .accessibilityLabel(
            "\(side == .front ? BookletLocalization.string("Front") : BookletLocalization.string("Back")): "
                + pairCaption(side == .back ? (sheet.back ?? sheet.front) : sheet.front)
        )
    }

    private func pairCaption(_ sheet: OutputSheet) -> String {
        BookletLocalization.string("Pages %lld and %lld", Int64(sheet.leftPage), Int64(sheet.rightPage))
    }

    // MARK: - Step 5: review

    private var reviewContent: some View {
        ScrollView {
            VStack(spacing: 14) {
                VStack(spacing: 10) {
                    reviewRow(BookletLocalization.string("Paper"), value: viewModel.settings.outputPaper.displayName,
                              systemImage: "rectangle.portrait.on.rectangle.portrait")
                    reviewRow(BookletLocalization.string("Layout"), value: BookletLocalization.string(viewModel.settings.layout.displayName),
                              systemImage: "rectangle.split.2x1")
                    if viewModel.settings.layout == .signatureFold {
                        reviewRow(BookletLocalization.string("Pages per signature"),
                                  value: BookletLocalization.string("%lld pages", Int64(viewModel.settings.signaturePageCount)),
                                  systemImage: "rectangle.stack")
                    }
                    reviewRow(BookletLocalization.string("Margin"),
                              value: BookletLocalization.string("%lld mm", Int64(viewModel.settings.marginMM)),
                              systemImage: "arrow.left.and.right")
                    reviewRow(BookletLocalization.string("Gutter"),
                              value: BookletLocalization.string("%lld mm", Int64(viewModel.settings.gutterMM)),
                              systemImage: "arrow.left.and.right.square")
                    reviewRow(BookletLocalization.string("Cut Marks"),
                              value: viewModel.settings.addCutMarks
                                  ? BookletLocalization.string("On") : BookletLocalization.string("Off"),
                              systemImage: "scissors")
                }
                .padding(13)
                .background(BookletMobileStyle.card, in: RoundedRectangle(cornerRadius: 14))

                readingPreview
            }
            .padding(16)
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
        }
    }

    private func reviewRow(_ title: String, value: String, systemImage: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .frame(width: 22)
                .foregroundStyle(.secondary)
            Text(title)
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
        .font(.subheadline)
    }

    private var readingPreview: some View {
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(BookletLocalization.string("Preview the booklet"))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                HStack(spacing: 8) {
                    Text("\(reviewCurrentPage)/\(reviewPageCount)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)

                    if showsJumpToFirstPage {
                        Button {
                            jumpToReviewSpread(0)
                        } label: {
                            Image(systemName: "backward.end.fill")
                                .font(.caption.weight(.semibold))
                                .frame(width: 28, height: 28)
                                .background(BookletMobileStyle.card, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(BookletMobileStyle.accent)
                        .accessibilityLabel(BookletLocalization.string("Page %lld", Int64(1)))
                    }

                    if showsJumpToLastPage {
                        Button {
                            jumpToReviewSpread(reviewLastSpreadIndex)
                        } label: {
                            Image(systemName: "forward.end.fill")
                                .font(.caption.weight(.semibold))
                                .frame(width: 28, height: 28)
                                .background(BookletMobileStyle.card, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(BookletMobileStyle.accent)
                        .accessibilityLabel(BookletLocalization.string("Page %lld", Int64(reviewPageCount)))
                    }
                }
            }
            FlipBookView(document: viewModel.currentDocument, spreadIndex: $reviewSpreadIndex)
            .frame(height: 280)
        }
    }

    private func jumpToReviewSpread(_ index: Int) {
        withAnimation(.easeInOut(duration: 0.2)) {
            reviewSpreadIndex = index
        }
    }

    // MARK: - Step 6: export

    private var exportContent: some View {
        let outputURL = viewModel.isBusy ? nil : viewModel.lastOutputURL

        return ScrollView {
            VStack(spacing: 15) {
                Image(systemName: outputURL == nil ? "square.and.arrow.up" : "checkmark.seal.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(BookletMobileStyle.accent)
                    .padding(.top, 18)
                Text(outputURL == nil
                     ? BookletLocalization.string("Your booklet PDF will appear here")
                     : BookletLocalization.string("Your booklet PDF is ready"))
                    .font(.headline)
                    .multilineTextAlignment(.center)

                if let url = outputURL {
                    HStack(spacing: 12) {
                        PDFDocumentPageView(documentURL: url, pageNumber: 1)
                            .frame(width: 42, height: 56)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(url.lastPathComponent).font(.subheadline.weight(.medium)).lineLimit(1)
                            Text(BookletLocalization.string("%lld print sides", Int64(viewModel.expectedOutputPageCount)))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(12)
                    .background(BookletMobileStyle.card, in: RoundedRectangle(cornerRadius: 12))
                    HStack(spacing: 10) {
                        Button(action: onShare) {
                            Label(BookletLocalization.string("Share"), systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        Button(action: onSave) {
                            Label(BookletLocalization.string("Save to Files"), systemImage: "folder")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                    .controlSize(.large)
                }
            }
            .padding(20)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Navigation

    private var footer: some View {
        VStack(spacing: 8) {
            if viewModel.isBusy {
                ProgressView(value: viewModel.progress)
                HStack {
                    Text(viewModel.isCancelling
                         ? BookletLocalization.string("Cancelling…")
                         : BookletLocalization.string("Generating…"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if !viewModel.isCancelling {
                        Button(BookletLocalization.string("Cancel")) { viewModel.cancel() }
                            .font(.footnote)
                    }
                }
            } else {
                HStack(spacing: 10) {
                    if currentStage != .printLayout || onReturnToGuide != nil {
                        Button {
                            if currentStage == .printLayout {
                                onReturnToGuide?()
                            } else {
                                currentStage = previousStage
                            }
                        } label: {
                            Label(BookletLocalization.string("Previous"), systemImage: "chevron.left")
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("booklet.stepPrevious")
                    }
                    Button(action: advanceStage) {
                        Label(primaryActionTitle, systemImage: primaryActionSymbol)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(currentStage == .review && !viewModel.canExportBooklet)
                    .accessibilityIdentifier("booklet.stepNext")
                }
                .controlSize(.large)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
        .frame(maxWidth: 680)
        .frame(maxWidth: .infinity)
    }

    private var previousStage: BookletStage {
        switch currentStage {
        case .printLayout: .printLayout
        case .paperSelection, .cuttingMarks: .printLayout
        case .bindingEffect, .review: .paperSelection
        case .export: .review
        }
    }

    private var primaryActionTitle: String {
        switch currentStage {
        case .printLayout, .paperSelection, .cuttingMarks:
            BookletLocalization.string("Next")
        case .bindingEffect, .review:
            BookletLocalization.string("Make Booklet")
        case .export:
            viewModel.lastOutputURL == nil
                ? BookletLocalization.string("Make Booklet")
                : BookletLocalization.string("Done")
        }
    }

    private var primaryActionSymbol: String {
        switch currentStage {
        case .printLayout, .paperSelection, .cuttingMarks: "chevron.right"
        case .bindingEffect, .review: "book.closed"
        case .export: viewModel.lastOutputURL == nil ? "book.closed" : "checkmark"
        }
    }

    private func advanceStage() {
        switch currentStage {
        case .printLayout:
            currentStage = .paperSelection
        case .paperSelection, .cuttingMarks:
            currentStage = .review
        case .bindingEffect, .review:
            currentStage = .export
            onExport()
        case .export:
            if viewModel.lastOutputURL == nil {
                onExport()
            } else {
                onFinish()
            }
        }
    }
}
#endif
