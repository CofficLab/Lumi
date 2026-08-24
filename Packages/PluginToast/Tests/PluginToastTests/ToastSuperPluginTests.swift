import KernelCore
import ProviderToast
import Testing
@testable import PluginToast

@MainActor
@Test func toastPluginReplacesTheDefaultProvider() throws {
    let kernel = KernelCoreContainer()
    try kernel.registerProvider((any ToastProviding).self, DefaultToastProviding())

    let plugin = ToastSuperPlugin()
    try plugin.onBoot(kernel: kernel)

    #expect(kernel.resolveProvider((any ToastProviding).self) === plugin.center)
}

@MainActor
@Test func dismissClearsTheCurrentToast() {
    let center = ToastCenter()
    center.show(LumiToast(title: "Saved", style: .success))
    #expect(center.currentToast?.title == "Saved")
    center.dismiss()
    #expect(center.currentToast == nil)
}
