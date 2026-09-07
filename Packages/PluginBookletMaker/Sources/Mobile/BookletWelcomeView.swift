#if os(iOS)
import SwiftUI

/// 欢迎页：主动选择"打开 PDF"或"使用示例 PDF"，不伪造最近文件。
struct BookletWelcomeView: View {
    @ObservedObject var feature: BookletMakerMobileFeature
    let onOpenPDF: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label(
                BookletLocalization.string("Make booklets or split PDFs"),
                systemImage: "doc.on.doc"
            )
        } description: {
            Text(BookletLocalization.string(
                "Turn a PDF into a folded booklet or split it into multiple files."
            ))
        } actions: {
            VStack(spacing: 12) {
                Button(action: onOpenPDF) {
                    Label(BookletLocalization.string("Open PDF"), systemImage: "folder")
                        .frame(maxWidth: 280)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button(action: { feature.openSampleDocument() }) {
                    Label(
                        BookletLocalization.string("Use Sample PDF"),
                        systemImage: "book"
                    )
                    .frame(maxWidth: 280)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
        .navigationTitle(BookletLocalization.string("BookletMaker"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        // 帮助与关于在 T6 接入
                    } label: {
                        Label(BookletLocalization.string("Help"), systemImage: "questionmark.circle")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel(BookletLocalization.string("More"))
            }
        }
        .overlay(alignment: .top) {
            if let message = feature.sessionErrorMessage {
                sessionErrorBanner(message)
            }
        }
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
