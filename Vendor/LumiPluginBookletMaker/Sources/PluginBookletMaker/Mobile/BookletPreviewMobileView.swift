#if os(iOS)
import SwiftUI

/// Booklet workflow: print-side preview, settings, review, then export.
struct BookletPreviewMobileView: View {
    @ObservedObject var viewModel: BookletMakerViewModel
    let onExport: () -> Void
    let onShare: () -> Void
    let onSave: () -> Void
    let onReturnToGuide: (() -> Void)?
    let onFinish: () -> Void

    var body: some View {
        BookletPreviewStageView(
            viewModel: viewModel,
            onExport: onExport,
            onShare: onShare,
            onSave: onSave,
            onReturnToGuide: onReturnToGuide,
            onFinish: onFinish
        )
        .navigationTitle(viewModel.currentDocument.baseFileName)
    }
}
#endif
