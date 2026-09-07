#if os(iOS)
import SwiftUI

/// 拼版预览阶段：按打印面顺序展示每一张纸的正反两面，
/// 提供纸张快捷选择；页序由 `BookletLayoutEngine` 单一生效。
/// 顶部为六阶段导航（参数 / 裁切 / 装订 / 总览 / 导出）。
struct BookletPreviewStageView: View {
    @ObservedObject var viewModel: BookletMakerViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let onExport: () -> Void

    @State private var currentStage: BookletStage = .printLayout

    private var outputSides: [OutputSheet] {
        BookletLayoutEngine.buildOutputSides(
            inputPageCount: viewModel.currentDocument.pageCount,
            settings: viewModel.settings
        )
    }

    private var gridColumns: [GridItem] {
        switch horizontalSizeClass {
        case .regular:
            [GridItem(.flexible(), spacing: 12),
             GridItem(.flexible(), spacing: 12),
             GridItem(.flexible())]
        default:
            [GridItem(.flexible(), spacing: 12),
             GridItem(.flexible())]
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            stageIndicator

            Divider()

            stageContent
        }
    }

    // MARK: - Stage routing

    @ViewBuilder
    private var stageContent: some View {
        switch currentStage {
        case .printLayout:
            printLayoutContent
        case .paperSelection, .cuttingMarks:
            BookletParameterPanelView(viewModel: viewModel)
        case .bindingEffect:
            BookletBindingEffectView(viewModel: viewModel)
        case .review, .export:
            reviewContent
        }
    }

    // MARK: - Stage indicator

    private var stageIndicator: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(Array(BookletStage.allCases.enumerated()), id: \.element) { index, stage in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            currentStage = stage
                        }
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: stage.systemImage)
                                .font(.footnote)
                            Text(stage.title)
                                .font(.caption2)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            stage == currentStage
                                ? Color.accentColor.opacity(0.14)
                                : Color.clear,
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                        .foregroundStyle(stage == currentStage ? Color.accentColor : Color.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(stage.title)
                    .accessibilityAddTraits(stage == currentStage ? .isSelected : [])

                    if index < BookletStage.allCases.count - 1 {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.25))
                            .frame(width: 6, height: 1)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }

    // MARK: - Print layout

    private var printLayoutContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                summaryCard
                paperPickerCard
                sheetGrid
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private var summaryCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle")
                .foregroundStyle(Color.accentColor)
            Text(BookletLocalization.string(
                "%lld pages → %lld sheets, %lld print sides",
                Int64(viewModel.currentDocument.pageCount),
                Int64(viewModel.expectedSheetCount),
                Int64(outputSides.count)
            ))
            .font(.footnote)
            Spacer()
        }
        .padding(10)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
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
        }
        .padding(10)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    private var sheetGrid: some View {
        LazyVGrid(columns: gridColumns, spacing: 16) {
            ForEach(outputSides, id: \.index) { outputSide in
                outputSideCard(outputSide)
            }
        }
    }

    private func outputSideCard(_ outputSide: OutputSheet) -> some View {
        VStack(spacing: 5) {
            HStack {
                sideBadge(outputSide.side)
                Spacer()
                Text(pairCaption(outputSide))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            OutputSheetView(
                sheet: outputSide,
                document: viewModel.currentDocument,
                settings: viewModel.settings
            )
            .frame(height: 128)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                BookletLocalization.string(
                    "Print side %lld: pages %lld and %lld",
                    Int64(outputSide.index + 1),
                    Int64(outputSide.leftPage),
                    Int64(outputSide.rightPage)
                )
            )
        }
        .padding(8)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func sideBadge(_ side: OutputSheet.Side) -> some View {
        let text = side == .front
            ? BookletLocalization.string("Front")
            : BookletLocalization.string("Back")
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(
                side == .front ? Color.accentColor.opacity(0.16) : Color.secondary.opacity(0.14),
                in: Capsule()
            )
            .foregroundStyle(side == .front ? Color.accentColor : Color.secondary)
    }

    private func pairCaption(_ sheet: OutputSheet) -> String {
        BookletLocalization.string("Pages %lld and %lld",
                                   Int64(sheet.leftPage),
                                   Int64(sheet.rightPage))
    }

    // MARK: - Review

    private var reviewContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 10) {
                    reviewRow(
                        BookletLocalization.string("Paper"),
                        value: viewModel.settings.outputPaper.displayName,
                        systemImage: "rectangle.portrait.on.rectangle.portrait"
                    )
                    reviewRow(
                        BookletLocalization.string("Layout"),
                        value: viewModel.settings.layout == .bookletFold
                            ? BookletLocalization.string("Booklet Fold")
                            : BookletLocalization.string("Simple Pair"),
                        systemImage: "rectangle.split.2x1"
                    )
                    reviewRow(
                        BookletLocalization.string("Margin"),
                        value: BookletLocalization.string("%lld mm", Int64(viewModel.settings.marginMM)),
                        systemImage: "arrow.left.and.right"
                    )
                    reviewRow(
                        BookletLocalization.string("Gutter"),
                        value: BookletLocalization.string("%lld mm", Int64(viewModel.settings.gutterMM)),
                        systemImage: "arrow.left.and.right.square"
                    )
                    reviewRow(
                        BookletLocalization.string("Cut Marks"),
                        value: viewModel.settings.addCutMarks
                            ? BookletLocalization.string("On")
                            : BookletLocalization.string("Off"),
                        systemImage: "scissors"
                    )
                }
                .padding(12)
                .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))

                summaryCard

                Button(action: onExport) {
                    Label(BookletLocalization.string("Make Booklet"), systemImage: "book.closed")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!viewModel.canExportBooklet)
            }
            .padding(16)
        }
    }

    private func reviewRow(_ title: String, value: String, systemImage: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .frame(width: 22)
                .foregroundStyle(.secondary)
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
        .font(.body)
    }
}
#endif
