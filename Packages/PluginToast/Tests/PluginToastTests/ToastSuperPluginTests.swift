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

@MainActor
@Test func toastCenterPublishesTypedEvents() {
    let center = ToastCenter()
    var events: [ToastProvidingEvent] = []
    let handle = center.addObserver { events.append($0) }
    let toast = LumiToast(title: "Saved", style: .success)

    center.show(toast)
    center.dismiss()
    handle.cancel()
    center.show(LumiToast(title: "Ignored"))

    #expect(events.count == 2)
    guard events.count == 2 else { return }
    if case let .currentToastChanged(value) = events[0] {
        #expect(value == toast)
    } else {
        Issue.record("expected currentToastChanged")
    }
    if case let .currentToastChanged(value) = events[1] {
        #expect(value == nil)
    } else {
        Issue.record("expected currentToastChanged")
    }
}
