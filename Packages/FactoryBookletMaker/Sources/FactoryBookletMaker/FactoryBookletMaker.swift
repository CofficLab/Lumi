import KernelCore
import SwiftUI

#if os(iOS)
import BookletMakerPlugin
#endif

@MainActor
public enum FactoryBookletMaker {
    public static func makeKernel() throws -> KernelCoreContainer {
        try KernelFactory.makeKernel()
    }

    public static func makeMainView(kernel: KernelCoreContainer) throws -> AnyView {
        try KernelFactory.makeMainView(kernel: kernel)
    }

    /// 使用已装配的内核组装设置视图，供专用 App 的 `Window` scene 使用。
    public static func makeSettingsView(kernel: KernelCoreContainer) throws -> AnyView {
        try KernelFactory.makeSettingsView(kernel: kernel)
    }

    #if os(iOS)
    /// iOS 使用小册子插件提供的移动端业务 façade；窗口导航与文件导入由 App 负责。
    public static func makeMobileFeature() -> BookletMakerMobileFeature {
        BookletMakerMobileFeature()
    }
    #endif
}
