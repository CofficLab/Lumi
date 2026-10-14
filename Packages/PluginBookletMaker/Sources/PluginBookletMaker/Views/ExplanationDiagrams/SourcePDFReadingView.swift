#if os(iOS)
import SwiftUI

/// 原稿阅读：以真实页面内容只读展示用户 PDF，支持双指缩放与拖动，
/// 页序保持原样（1…N），底部提供章节/页码导航。
struct SourcePDFReadingView: View {
    let document: CurrentPDFDocument

    @State private var currentPage: Int = 1
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var showsPageList = false

    private var pageCount: Int { document.pageCount }

    var body: some View {
        VStack(spacing: 0) {
            reader

            pageNavigator
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Reader

    private var reader: some View {
        GeometryReader { geo in
            let pageAspect = document.pageAspectRatio
            ScrollView([.horizontal, .vertical]) {
                PDFDocumentPageView(
                    documentURL: document.url,
                    pageNumber: currentPage
                )
                .frame(
                    width: geo.size.width * pageAspect * scale,
                    height: geo.size.height * scale
                )
            }
            .scrollIndicators(.hidden)
            .gesture(magnificationGesture)
        }
        .overlay(alignment: .topTrailing) {
            zoomControls
                .padding(8)
        }
        .overlay(alignment: .topLeading) {
            pageBadge
                .padding(8)
        }
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = min(5, max(1, lastScale * value))
            }
            .onEnded { value in
                lastScale = min(5, max(1, lastScale * value))
                scale = lastScale
            }
    }

    private var zoomControls: some View {
        VStack(spacing: 6) {
            Button {
                withAnimation { scale = 1; lastScale = 1 }
            } label: {
                Image(systemName: "arrow.counterclockwise")
            }
            Button {
                withAnimation { scale = min(5, scale * 1.4); lastScale = scale }
            } label: {
                Image(systemName: "plus.magnifyingglass")
            }
            Button {
                withAnimation { scale = max(1, scale / 1.4); lastScale = scale }
            } label: {
                Image(systemName: "minus.magnifyingglass")
            }
        }
        .font(.body)
        .buttonStyle(.bordered)
        .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 10))
        .accessibilityLabel(BookletLocalization.string("Zoom"))
    }

    private var pageBadge: some View {
        Text(BookletLocalization.string("Page %lld of %lld",
                                        Int64(currentPage),
                                        Int64(pageCount)))
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.thickMaterial, in: Capsule())
            .accessibilityHidden(false)
    }

    // MARK: - Navigator

    private var pageNavigator: some View {
        HStack(spacing: 12) {
            Button {
                go(to: currentPage - 1)
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 28)
            }
            .disabled(currentPage <= 1)
            .accessibilityLabel(BookletLocalization.string("Previous page"))

            Button {
                showsPageList = true
            } label: {
                Text(BookletLocalization.string("Page %lld / %lld",
                                                Int64(currentPage),
                                                Int64(pageCount)))
                    .font(.subheadline.weight(.medium))
                    .frame(minWidth: 88)
            }
            .buttonStyle(.bordered)

            Button {
                go(to: currentPage + 1)
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 28)
            }
            .disabled(currentPage >= pageCount)
            .accessibilityLabel(BookletLocalization.string("Next page"))
        }
        .padding(.vertical, 8)
        .background(.bar)
        .confirmationDialog(
            BookletLocalization.string("Jump to page"),
            isPresented: $showsPageList,
            titleVisibility: .visible
        ) {
            ForEach(1...pageCount, id: \.self) { page in
                Button(BookletLocalization.string("Page %lld", Int64(page))) {
                    go(to: page)
                }
            }
        }
    }

    private func go(to page: Int) {
        guard (1...pageCount).contains(page) else { return }
        currentPage = page
        scale = 1
        lastScale = 1
    }
}
#endif
