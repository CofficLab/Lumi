import LumiUI
import SwiftUI

/// Workspace for ordering and merging several PDF files.
struct PDFMergeWorkspaceView: View {
    @ObservedObject var viewModel: BookletMakerViewModel

    @ViewBuilder
    private var content: some View {
        if viewModel.mergeDocuments.isEmpty {
            AppEmptyState(
                icon: "doc.badge.plus",
                title: BookletLocalization.string("No PDF files selected"),
                description: BookletLocalization.string("Choose or drop at least two PDF files to begin.")
            )
            .accessibilityIdentifier("merge.emptyState")
        } else {
            List {
                ForEach(Array(viewModel.mergeDocuments.enumerated()), id: \.element.id) { index, item in
                    HStack(spacing: 12) {
                        Text("\(index + 1)")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 24)
                        Image(systemName: "doc.fill")
                            .foregroundStyle(Color.accentColor)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.url.lastPathComponent)
                                .lineLimit(1)
                            Text(BookletLocalization.string("%lld pages", Int64(item.pageCount)))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                // 页数单独挂锚点：外层行的 value 在辅助功能树里
                                // 读不到（整行被折叠成组），而顺序断言又必须知道
                                // 每项的页数。只暴露页数，不暴露文件名。
                                .accessibilityIdentifier("merge.file.\(index + 1).pageCount")
                        }
                        Spacer()
                        // 行内按钮：右键菜单在辅助功能树里不可靠地可达，
                        // 排序与删除是高频操作，值得显式呈现而不是藏在菜单里。
                        queueControls(index: index, item: item)
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .contain)
                    // 用队列位置而非 UUID 定位：UUID 每次启动都变，
                    // UI 测试无法跨启动引用；位置才是用户认知中的「第一个文件」。
                    .accessibilityIdentifier("merge.file.\(index + 1)")
                    // 只暴露页数，不暴露文件名：文件名可能是 UUID（测试夹具）或
                    // 用户隐私路径，页数既能唯一标识顺序变化，又不泄露内容。
                    // 界面测试据此判定每项的页数顺序。
                    .accessibilityValue(String(item.pageCount))
                }
                .onMove { offsets, destination in
                    viewModel.moveMergeDocuments(from: offsets, to: destination)
                }
            }
            .accessibilityIdentifier("merge.fileList")
        }
    }

    /// 队列项的行内操作：上移 / 下移 / 移除。
    ///
    /// 用图标按钮而非文字，避免窄区域里挤压文件名；`help` 提供悬停说明。
    @ViewBuilder
    private func queueControls(index: Int, item: PDFMergeItem) -> some View {
        let isFirst = index == 0
        let isLast = index == viewModel.mergeDocuments.count - 1

        HStack(spacing: 2) {
            Button {
                viewModel.moveMergeDocument(item, offsetBy: -1)
            } label: {
                Image(systemName: "chevron.up")
            }
            .disabled(isFirst)
            .help(BookletLocalization.string("Move up"))
            .accessibilityLabel(BookletLocalization.string("Move up"))
            .accessibilityIdentifier("merge.file.\(index + 1).moveUp")

            Button {
                viewModel.moveMergeDocument(item, offsetBy: 1)
            } label: {
                Image(systemName: "chevron.down")
            }
            .disabled(isLast)
            .help(BookletLocalization.string("Move down"))
            .accessibilityLabel(BookletLocalization.string("Move down"))
            .accessibilityIdentifier("merge.file.\(index + 1).moveDown")

            Button {
                viewModel.removeMergeDocument(item)
            } label: {
                Image(systemName: "trash")
            }
            .help(BookletLocalization.string("Remove"))
            .accessibilityLabel(BookletLocalization.string("Remove"))
            .accessibilityIdentifier("merge.file.\(index + 1).remove")
        }
        .buttonStyle(.borderless)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(BookletLocalization.string("Merge PDF Files"))
                        .font(.title2.weight(.semibold))
                    Text(BookletLocalization.string(
                        "Arrange the files, then export one combined PDF."
                    ))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                Label(
                    BookletLocalization.string(
                        "%lld files · %lld pages",
                        Int64(viewModel.mergeDocuments.count),
                        Int64(viewModel.mergePageCount)
                    ),
                    systemImage: "doc.on.doc"
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("merge.summary")
            }
            .padding()

            Divider()

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
