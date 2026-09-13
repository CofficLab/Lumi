import Testing
@testable import ProviderDeveloperMode

@Suite("ProviderDeveloperMode")
@MainActor
struct DeveloperModeProvidingTests {
    @Test("defaults to disabled and toggles at runtime")
    func defaultsAndToggle() {
        let provider = DefaultDeveloperModeProviding()

        #expect(provider.isEnabled == false)
        provider.toggle()
        #expect(provider.isEnabled == true)
        provider.setEnabled(false)
        #expect(provider.isEnabled == false)
    }

    @Test("typed observer only receives actual value changes")
    func observesChanges() {
        let provider = DefaultDeveloperModeProviding()
        var received: [Bool] = []
        let handle = provider.addObserver { event in
            guard case let .enabledChanged(isEnabled) = event else { return }
            received.append(isEnabled)
        }

        provider.setEnabled(false)
        provider.setEnabled(true)
        provider.setEnabled(true)
        provider.setEnabled(false)

        #expect(received == [true, false])
        handle.cancel()
        provider.setEnabled(true)
        #expect(received == [true, false])
    }

    @Test("cancelling twice is safe")
    func doubleCancelIsIdempotent() {
        let provider = DefaultDeveloperModeProviding()
        var received: [Bool] = []
        let handle = provider.addObserver { event in
            guard case .enabledChanged(let value) = event else { return }
            received.append(value)
        }

        handle.cancel()
        handle.cancel()  // must not crash
        provider.setEnabled(true)
        #expect(received == [])
    }

    @Test("deallocated observers are pruned without affecting live ones")
    func deallocatedObserverIsPruned() {
        let provider = DefaultDeveloperModeProviding()
        var liveReceived: [Bool] = []
        let liveHandle = provider.addObserver { event in
            guard case .enabledChanged(let value) = event else { return }
            liveReceived.append(value)
        }

        // This observer handle is immediately dropped; the provider holds only
        // a weak reference, so the next notify must prune it without crashing.
        do {
            let transient = provider.addObserver { _ in }
            _ = transient
        }

        provider.toggle()
        provider.toggle()

        #expect(liveReceived == [true, false])
    }

}
