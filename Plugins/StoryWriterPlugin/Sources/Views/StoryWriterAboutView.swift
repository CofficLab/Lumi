import SwiftUI

// MARK: - Story Writer About View

/// Short description shown in the plugin's "About" pane.
struct StoryWriterAboutView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(LumiPluginLocalization.string("Story Writer"),
                  systemImage: "book.closed.fill")
                .font(.headline)

            Text(LumiPluginLocalization.string(
                "A two-pane workspace for crafting stories with AI assistance."
            ))
            .font(.subheadline)
            .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                Text(LumiPluginLocalization.string("Features"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Label(LumiPluginLocalization.string("Create and manage stories with chapters"),
                      systemImage: "doc.text")
                    .font(.caption)
                Label(LumiPluginLocalization.string("AI-assisted writing with 12 agent tools"),
                      systemImage: "sparkles")
                    .font(.caption)
                Label(LumiPluginLocalization.string("Markdown import and export"),
                      systemImage: "doc.badge.gearshape")
                    .font(.caption)
                Label(LumiPluginLocalization.string("Story outline rail tab"),
                      systemImage: "list.bullet.rectangle.portrait")
                    .font(.caption)
            }
        }
        .padding()
    }
}
