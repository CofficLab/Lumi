#if os(iOS)
import UIKit

/// iOS 分享面板呈现器。
///
/// BookletMaker 的导出在插件层（非 View）触发，无法直接用 SwiftUI `.share`。
/// 这里通过查找当前前台 `UIWindowScene` 的顶层 `UIViewController` 来呈现
/// `UIActivityViewController`，让用户把生成的 PDF 保存到「文件」或分享。
enum SharePresenter {
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
