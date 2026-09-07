#if os(macOS)
import KernelCore
import SwiftUI

/// BookletMaker 的 macOS 组装入口：内核、主视图与设置视图。
@MainActor
public enum FactoryBookletMakerMac {
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
}
#endif
