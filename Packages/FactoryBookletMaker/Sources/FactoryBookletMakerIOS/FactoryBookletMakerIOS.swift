#if os(iOS)
import BookletMakerPlugin
import SwiftUI

/// BookletMaker 的 iOS 组装入口：移动端业务 façade。
///
/// App 只调用组装入口；移动会话（feature）在根视图中以 `@StateObject`
/// 持有，窗口导航与文件导入统一由根视图管理。
@MainActor
public enum FactoryBookletMakerIOS {
    public static func makeMobileFeature() -> BookletMakerMobileFeature {
        BookletMakerMobileFeature()
    }

    public static func makeMobileRootView() -> BookletMakerMobileRootView {
        BookletMakerMobileRootView(feature: BookletMakerMobileFeature())
    }
}
#endif
