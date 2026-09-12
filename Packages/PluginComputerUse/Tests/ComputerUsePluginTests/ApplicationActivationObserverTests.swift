import AppKit
import Testing
@testable import ComputerUsePlugin

@Test @MainActor func activationObserverCallsBackUntilCancelled() {
    let counter = ActivationCounter()
    let observer = ApplicationActivationObserver { counter.value += 1 }

    NotificationCenter.default.post(name: NSApplication.didBecomeActiveNotification, object: nil)
    #expect(counter.value == 1)

    observer.cancel()
    observer.cancel()
    NotificationCenter.default.post(name: NSApplication.didBecomeActiveNotification, object: nil)
    #expect(counter.value == 1)
}

@MainActor
private final class ActivationCounter {
    var value = 0
}
