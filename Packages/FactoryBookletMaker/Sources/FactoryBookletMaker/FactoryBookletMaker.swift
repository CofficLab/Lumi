import FactoryLumi
import KernelCore
import SwiftUI

@MainActor
public enum FactoryBookletMaker {
    public static func makeKernel() throws -> KernelCoreContainer {
        try KernelFactory.makeKernel()
    }

    public static func makeMainView(kernel: KernelCoreContainer) throws -> AnyView {
        try KernelFactory.makeMainView(kernel: kernel)
    }

    /// 使用已装配的内核组装设置视图，供专用 App 的原生 `Settings` scene 使用。
    public static func makeSettingsView(kernel: KernelCoreContainer) throws -> AnyView {
        try KernelFactory.makeSettingsView(kernel: kernel)
    }
}
