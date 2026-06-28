import Combine
import SwiftUI

/// Compatibility bridge for legacy editor views that expect `AppThemeVM` on the environment.
@MainActor
public final class AppThemeVM: ObservableObject {
    public static let shared = AppThemeVM()

    private let registry: LumiUIThemeRegistry
    private var cancellable: AnyCancellable?

    public var activeChromeTheme: any LumiAppChromeTheme {
        registry.chromeTheme
    }

    public init(registry: LumiUIThemeRegistry = .shared) {
        self.registry = registry
        cancellable = registry.objectWillChange.sink { [weak self] _ in
            Task { @MainActor in
                self?.objectWillChange.send()
            }
        }
    }
}
