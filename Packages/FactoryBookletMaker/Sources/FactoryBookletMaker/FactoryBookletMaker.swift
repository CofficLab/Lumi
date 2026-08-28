import FactoryLumi
import KernelCore
import SwiftUI

/// V2 composition root for the BookletMaker specialist app.
@MainActor
public enum FactoryBookletMaker {
    public static func makeKernel() throws -> KernelCoreContainer {
        try KernelFactory.makeKernel()
    }

    public static func makeMainView(kernel: KernelCoreContainer) throws -> AnyView {
        try KernelFactory.makeMainView(kernel: kernel)
    }

    public static func makeSettingsView(kernel: KernelCoreContainer) throws -> AnyView {
        try KernelFactory.makeSettingsView(kernel: kernel)
    }
}
