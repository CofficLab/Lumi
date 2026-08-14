import Foundation
import KernelLumi
import Testing
@testable import ToastPlugin

@MainActor
@Test func toastCenterShowsLatestToast() async throws {
    let center = ToastCenter()

    center.show(LumiToast(title: "First", style: .info))
    #expect(center.currentToast?.title == "First")

    center.show(LumiToast(title: "Second", detail: "replaced", style: .success))
    #expect(center.currentToast?.title == "Second")
    #expect(center.currentToast?.detail == "replaced")
    #expect(center.currentToast?.style == .success)
}

@MainActor
@Test func toastCenterDismissClearsCurrentToast() async throws {
    let center = ToastCenter()

    center.show(LumiToast(title: "Hello", duration: 60))
    #expect(center.currentToast != nil)

    center.dismiss()
    #expect(center.currentToast == nil)
}

@MainActor
@Test func toastProvidingConvenienceOverload() async throws {
    let center = ToastCenter()

    center.show("Saved", detail: "All changes written", style: .success, duration: 1.5)

    #expect(center.currentToast == LumiToast(
        title: "Saved",
        detail: "All changes written",
        style: .success,
        duration: 1.5
    ))
}
