#if os(iOS)
import SwiftUI
import UIKit

/// iOS 分享面板呈现器。
///
/// 新的 SwiftUI 优先路径使用 ``ShareSheet``（`UIViewControllerRepresentable`）
/// 通过 `.sheet` 呈现，无需再查找前台窗口；支持一次分享多个文件 URL。
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

    /// 旧路径：通过前台窗口顶层控制器呈现（插件路径仍在使用，
    /// 重构完成后随插件路径一起移除）。
    @MainActor
    static func share(fileURL: URL) {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let root = (scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first)?.rootViewController
        else {
            return
        }

        var top = root
        while let presented = top.presentedViewController {
            top = presented
        }

        let activity = UIActivityViewController(
            activityItems: [fileURL],
            applicationActivities: nil
        )
        top.present(activity, animated: true)
    }
}
#endif
