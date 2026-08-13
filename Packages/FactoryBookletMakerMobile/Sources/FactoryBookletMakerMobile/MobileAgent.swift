import UIKit

/// BookletMaker iOS 宿主的应用代理。应用级 URL、文件打开和生命周期
/// 行为在此处扩展，不进入通用工厂。
@MainActor
public final class MobileAgent: NSObject, UIApplicationDelegate {
    public func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        true
    }
}
