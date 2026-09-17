import Foundation
import CoreGraphics
import Testing
@testable import ComputerUsePlugin

@Test func revokedInputLeaseCannotBeRestarted() throws {
    let session = NativeControlSession()
    session.start()
    try session.check()
    session.interrupt(.userInput)
    session.start()
    #expect(throws: NativeControlInterruption.userInput) { try session.check() }
    session.interrupt(.stopped)
    #expect(throws: NativeControlInterruption.userInput) { try session.check() }
}

@Test func expiredLeaseRejectsFurtherInput() {
    let session = NativeControlSession()
    session.start(duration: .zero)
    #expect(throws: NativeControlInterruption.timedOut) { try session.check() }
}

@Test func eventMarkerAloneCannotMasqueradeAsLumi() throws {
    let event = try #require(CGEvent(source: nil))
    event.setIntegerValueField(.eventSourceUserData, value: NativeControlSession.eventMarker)
    event.setIntegerValueField(.eventSourceUnixProcessID, value: -1)
    #expect(!NativeControlSession.isOwnEvent(event))
    event.setIntegerValueField(.eventSourceUnixProcessID, value: Int64(ProcessInfo.processInfo.processIdentifier))
    #expect(NativeControlSession.isOwnEvent(event))
}

@MainActor
@Test func nativeControlHoldsExclusiveLeaseAndStopRequiresFreshConsent() throws {
    let suite = "ComputerUse.Native.\(UUID())"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let controller = NativeControlCoordinator(defaults: defaults, presentsUI: false)
    let first = try controller.acquire(application: "Fixture", bundleID: "test.app", reason: "Test")
    #expect(controller.phase == .permission)
    controller.allow()
    #expect(throws: (any Error).self) { try controller.acquire(application: "Other", bundleID: "test.other", reason: "Test") }
    controller.release(first)
    let second = try controller.acquire(application: "Fixture", bundleID: "test.app", reason: "Test")
    #expect(controller.phase == .preparing)
    controller.release(first) // late cleanup must not release another operation
    #expect(controller.isBusy)
    controller.stop()
    #expect(!controller.blocksLumi)
    controller.release(second)
    let third = try controller.acquire(application: "Fixture", bundleID: "test.app", reason: "Test")
    #expect(controller.phase == .permission)
    controller.release(third)
    #expect(!controller.isBusy)
}

@MainActor
@Test func resumeRequiresFreshObservationAndNeverReplaysBatch() async throws {
    let suite = "ComputerUse.Resume.\(UUID())"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let controller = NativeControlCoordinator(defaults: defaults, presentsUI: false)
    let session = try controller.acquire(application: "Fixture", bundleID: "test.app", reason: "Test")
    session.interrupt(.userInput)
    let waiter = Task { try await controller.waitForUserAfterInterruption(session) }
    while controller.phase != .paused { await Task.yield() }
    #expect(!controller.blocksLumi)
    controller.resume()
    do {
        try await waiter.value
        Issue.record("Must require a new observation")
    } catch let error as ComputerUseError {
        #expect(error.localizedDescription.contains("observe"))
    }
    #expect(throws: NativeControlInterruption.userInput) { try session.check() }
    controller.release(session)
}

@MainActor
@Test func cancellationWhileAwaitingConsentReleasesUI() async throws {
    let suite = "ComputerUse.Cancel.\(UUID())"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let controller = NativeControlCoordinator(defaults: defaults, presentsUI: false)
    let session = try controller.acquire(application: "Fixture", bundleID: "test.app", reason: "Test")
    let task = Task {
        defer { controller.release(session) }
        try await controller.prepare(session)
    }
    task.cancel()
    do { try await task.value; Issue.record("Expected cancellation") } catch {}
    #expect(controller.phase == .idle)
    #expect(!controller.isBusy)
}
