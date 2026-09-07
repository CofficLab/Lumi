#if os(iOS)
import SwiftUI

/// 拼版预览阶段：按打印面顺序展示每一张纸的正反两面，
/// 提供纸张快捷选择；页序由 `BookletLayoutEngine` 单一生效。
struct BookletPreviewStageView: View {
    @ObservedObject var viewModel: BookletMakerViewModel
    let onStageChange: (BookletStage) -> Void

    private var outputSides: [OutputSheet] {
        BookletLayoutEngine.buildOutputSides(
            inputPageCount: viewModel.currentDocument.pageCount,
            settings: viewModel.settings
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                stageIndicator

                summaryCard

                paperPickerCard

                sheetGrid
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Stage indicator

    private var stageIndicator: some View {
        HStack(spacing: 0) {
            ForEach(Array(BookletStage.allCases.enumerated()), id: \.element) { index, stage in
                Button {
                    onStageChange(stage)
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: stage.systemImage)
                            .font(.footnote)
                        Text("\(stage.stepNumber)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(
                        stage == .printLayout
                            ? Color.accentColor.opacity(0.14)
                            : Color.clear,
                        in: RoundedRectangle(cornerRadius: 8)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(stage.title)
                .accessibilityAddTraits(stage == .printLayout ? .isSelected : [])

                if index < BookletStage.allCases.count - 1 {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.25))
                        .frame(width: 8, height: 1)
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Summary

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

    // MARK: - Paper picker

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

    // MARK: - Sheets grid

    private var sheetGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())],
            spacing: 16
        ) {
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
        BookletLocalization.string("Pages %lld + %lld",
                                   Int64(sheet.leftPage),
                                   Int64(sheet.rightPage))
    }
}
#endif
