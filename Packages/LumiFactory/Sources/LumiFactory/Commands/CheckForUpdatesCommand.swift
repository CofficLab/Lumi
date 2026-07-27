import SwiftUI

/// Check for updates command menu item.
///
/// Full implementation requires UpdateService + Sparkle (B1-4).
/// This stub provides the menu item placeholder.
struct CheckForUpdatesCommand: Commands {
    var body: some Commands {
        CommandGroup(after: .appInfo) {
            Button(String(localized: "Check for Updates...")) {
                // TODO: UpdateService.shared.checkForUpdates() (B1-4)
            }
            .disabled(true)
        }
    }
}
