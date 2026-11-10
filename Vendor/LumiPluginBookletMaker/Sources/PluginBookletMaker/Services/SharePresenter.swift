#if os(iOS)
import SwiftUI
import UIKit

/// iOS 分享面板呈现器。
///
/// SwiftUI 优先：通过 ``ShareSheet``（`UIViewControllerRepresentable`）
/// 在 `.sheet` 中呈现，无需查找前台窗口；支持一次分享多个文件 URL。
enum SharePresenter {
    /// 多文件分享面板，可嵌入 SwiftUI `.sheet`。
    struct ShareSheet: UIViewControllerRepresentable {
        let urls: [URL]

        func makeUIViewController(context: Context) -> UIActivityViewController {
            UIActivityViewController(
                activityItems: urls,
                applicationActivities: nil
            )
        }

        func updateUIViewController(_ uiViewController: UIActivityViewController,
                                    context: Context) {}
    }
}
#endif
