import UIKit

/// iOS 应用代理，对应 macOS 的 `MacAgent`。
///
/// 当前为最小实现；后续可在此处理 URL Scheme、文件打开、生命周期事件等。
@MainActor
public final class MobileAgent: NSObject, UIApplicationDelegate {
    public func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        true
    }
}
