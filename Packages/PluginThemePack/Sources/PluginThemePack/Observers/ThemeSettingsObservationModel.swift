import Combine
import ProviderTheme
import SwiftUI

/// Observes theme-provider changes for the theme settings page.
@MainActor
final class ThemeSettingsObservationModel: ObservableObject {
    @Published private(set) var revision = 0
    private var handle: (any ThemeProvidingObserverHandle)?

    init(theme: any ThemeProviding) {
        handle = theme.addObserver { [weak self] _ in
            self?.revision += 1
        }
    }

}
