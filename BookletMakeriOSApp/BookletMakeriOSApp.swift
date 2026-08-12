import SwiftUI

/// BookletMaker iOS 金丝雀入口。
///
/// 本阶段（Stage 2）只验证 Lumi.xcodeproj 能产出 iOS 二进制、并在模拟器启动。
/// 它**不依赖任何 Lumi 模块**；后续阶段会把它替换为由 `FactoryBookletMakerMobile`
/// 组装的真实界面。
@main
struct BookletMakeriOSApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            CanaryView()
        }
    }
}

private final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        true
    }
}

private struct CanaryView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "book")
                .font(.system(size: 48))
            Text("BookletMaker iOS")
                .font(.title2.bold())
            Text("canary")
                .foregroundStyle(.secondary)
        }
    }
}
