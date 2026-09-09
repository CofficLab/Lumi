import Testing
import Combine
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

    @Test("publishes changes only when the value changes")
    func publishesChanges() {
        let provider = DefaultDeveloperModeProviding()
        var received = 0
        let cancellable = provider.objectWillChange.sink { received += 1 }

        provider.setEnabled(false)
        provider.setEnabled(true)
        provider.setEnabled(true)
        provider.setEnabled(false)

        #expect(received == 2)
        cancellable.cancel()
        provider.setEnabled(true)
        #expect(received == 2)
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
