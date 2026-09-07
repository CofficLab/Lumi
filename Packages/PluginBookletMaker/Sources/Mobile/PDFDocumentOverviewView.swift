#if os(iOS)
import SwiftUI

/// 文档概览：已打开文件的根页面。展示文件信息与两个工具入口；
/// 菜单提供文件信息、更换 PDF、关闭当前 PDF（帮助与关于在 T6 接入）。
struct PDFDocumentOverviewView: View {
    @ObservedObject var feature: BookletMakerMobileFeature
    let onOpenPDF: () -> Void

    private var viewModel: BookletMakerViewModel { feature.viewModel }

    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    thumbnail
                    VStack(alignment: .leading, spacing: 4) {
                        Text(feature.documentName)
                            .font(.headline)
                            .lineLimit(2)
                        Text(pageCountText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section {
                NavigationLink(value: MobileWorkspaceState.Tool.booklet) {
                    toolRow(
                        title: BookletLocalization.string("Make Booklet"),
                        subtitle: BookletLocalization.string("Reorder pages for folded binding"),
                        systemImage: "book.closed"
                    )
                }

                NavigationLink(value: MobileWorkspaceState.Tool.split) {
                    toolRow(
                        title: BookletLocalization.string("Split PDF"),
                        subtitle: splitSubtitle,
                        systemImage: "scissors"
                    )
                }
            }
        }
        .navigationTitle(BookletLocalization.string("Document"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Section {
                        Label(feature.documentName, systemImage: "doc")
                        Label(pageCountText, systemImage: "number")
                        if let size = firstPageSizeText {
                            Label(size, systemImage: "ruler")
                        }
                        if feature.isDemo {
                            Label(BookletLocalization.string("Sample"), systemImage: "book")
                        }
                    }

                    Divider()

                    Button {
                        onOpenPDF()
                    } label: {
                        Label(BookletLocalization.string("Replace PDF…"), systemImage: "arrow.triangle.2.circlepath")
                    }

                    Button(role: .destructive) {
                        feature.closeDocument()
                    } label: {
                        Label(BookletLocalization.string("Close Current PDF"), systemImage: "xmark.circle")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel(BookletLocalization.string("Document menu"))
            }
        }
        .navigationDestination(for: MobileWorkspaceState.Tool.self) { tool in
            feature.makeContentView()
                .navigationBarTitleDisplayMode(.inline)
        }
        .overlay(alignment: .top) {
            if let message = feature.sessionErrorMessage {
                sessionErrorBanner(message)
            }
        }
    }

    private var thumbnail: some View {
        PDFDocumentPageView(
            documentURL: viewModel.currentDocument.url,
            pageNumber: 1
        )
        .frame(width: 56, height: 56 / viewModel.currentDocument.pageAspectRatio)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
        .accessibilityHidden(true)
    }

    private var pageCountText: String {
        BookletLocalization.string("%lld pages", Int64(feature.pageCount))
    }

    private var splitSubtitle: String {
        feature.pageCount >= 2
            ? BookletLocalization.string("Split after chosen pages into multiple files")
            : BookletLocalization.string("At least 2 pages are required")
    }

    private var firstPageSizeText: String? {
        let size = viewModel.currentDocument.info.firstPageSize
        guard size.width > 0, size.height > 0 else { return nil }
        return String(format: "%.0f × %.0f pt", size.width, size.height)
    }

    private func toolRow(title: String,
                         subtitle: String,
                         systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3)
                .frame(width: 32, height: 32)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private func sessionErrorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(message)
                .font(.subheadline)
            Spacer()
            Button {
                feature.dismissSessionError()
            } label: {
                Image(systemName: "xmark")
            }
            .accessibilityLabel(BookletLocalization.string("Dismiss"))
        }
        .padding(12)
        .background(.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
}
#endif
