import SwiftUI

// MARK: - Menu Bar Helper About View

/// Short description shown in the plugin's "About" pane.
struct MenuBarHelperAboutView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(LumiPluginLocalization.string("Menu Bar Manager", bundle: .module),
                  systemImage: "menubar.rectangle")
                .font(.headline)

            Text(LumiPluginLocalization.string(
                "Settings UI for managing menu bar item visibility.",
                bundle: .module
            ))
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding()
    }
}
