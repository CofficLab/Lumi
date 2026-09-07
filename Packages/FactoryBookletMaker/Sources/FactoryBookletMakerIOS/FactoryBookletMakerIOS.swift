#if os(iOS)
import BookletMakerPlugin

/// BookletMaker 的 iOS 组装入口：移动端业务 façade。
///
/// 窗口导航与文件导入由 App 负责。
@MainActor
public enum FactoryBookletMakerIOS {
    public static func makeMobileFeature() -> BookletMakerMobileFeature {
        BookletMakerMobileFeature()
    }
}
#endif
