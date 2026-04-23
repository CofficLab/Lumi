import SwiftUI

private struct EditorLoadedPluginsStatusBarView: View {
    var body: some View {
        StatusBarHoverContainer(
            detailView: EditorLoadedPluginsDetailView(),
            popoverWidth: 460,
            id: "lumi-editor-loaded-plugins"
        ) {
            HStack(spacing: 4) {
                Image(systemName: "puzzlepiece.extension")
                    .font(.system(size: 11))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }
}

struct EditorLoadedPluginsDetailView: View {
    @StateObject private var viewModel = EditorLoadedPluginsViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Editor Plugins")
                    .font(.system(size: 13, weight: .semibold))

                Spacer()

                Button {
                    viewModel.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.plain)
                .help("Refresh")
            }

            Text("Loaded \(viewModel.enabledPlugins.count) plugin(s)")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            if viewModel.enabledPlugins.isEmpty {
                Text("No editor plugins loaded")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(viewModel.enabledPlugins) { plugin in
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.green)
                                Text(plugin.displayName)
                                    .font(.system(size: 12, weight: .medium))
                                Spacer()
                                Text(plugin.id)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .frame(maxHeight: 240)
            }
        }
        .onAppear {
            viewModel.refresh()
        }
    }
}

@MainActor
final class EditorLoadedPluginsViewModel: ObservableObject {
    @Published var enabledPlugins: [EditorPluginManager.PluginInfo] = []

    func refresh() {
        let manager = EditorPluginManager()
        manager.autoDiscoverAndRegisterPlugins()
        enabledPlugins = manager.discoveredPluginInfos
            .filter(\.isEnabled)
    }
}
