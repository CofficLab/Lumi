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

    @Test("observation mirrors provider state")
    func observationMirrorsProvider() async {
        let provider = DefaultDeveloperModeProviding()
        let observation = DeveloperModeObservation(provider: provider)

        #expect(observation.isEnabled == false)
        provider.setEnabled(true)
        await Task.yield()
        #expect(observation.isEnabled == true)
    }
}
