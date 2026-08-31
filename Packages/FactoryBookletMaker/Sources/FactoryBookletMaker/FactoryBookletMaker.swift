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
}
