import MagicKit
import SwiftUI

struct EditorLoadedPluginsStatusBarView: View {
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
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var viewModel = EditorLoadedPluginsViewModel()

    private var rowBackground: Color {
        colorScheme == .light
            ? DesignTokens.Color.semantic.primary.opacity(0.06)
            : DesignTokens.Color.semantic.primary.opacity(0.14)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(String(localized: "Editor Plugins", table: "EditorLoadedPlugins"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                Spacer()

                Button {
                    viewModel.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                }
                .buttonStyle(.plain)
                .help(String(localized: "Refresh", table: "EditorLoadedPlugins"))
            }

            Text(
                String(
                    format: String(localized: "Loaded %lld plugin(s)", table: "EditorLoadedPlugins"),
                    Int64(viewModel.enabledPlugins.count)
                )
            )
                .font(.system(size: 11))
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)

            if viewModel.enabledPlugins.isEmpty {
                Text(String(localized: "No editor plugins loaded", table: "EditorLoadedPlugins"))
                    .font(.system(size: 12))
                    .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                    .padding(.vertical, 8)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(viewModel.enabledPlugins) { plugin in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(DesignTokens.Color.semantic.primary)
                                    .padding(.top, 2)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(plugin.displayName)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                                    Text(plugin.description)
                                        .font(.system(size: 11))
                                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                                        .lineLimit(2)
                                    Text(plugin.id)
                                        .font(.system(size: 10))
                                        .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                                        .lineLimit(1)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(rowBackground)
                            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm))
                        }
                    }
                }
                .frame(minHeight: 300)
            }
        }
        .onAppear {
            viewModel.refresh()
        }
    }
}

@MainActor
final class EditorLoadedPluginsViewModel: ObservableObject {
    struct PluginInfo: Identifiable {
        let id: String
        let displayName: String
        let description: String
    }

    @Published var enabledPlugins: [PluginInfo] = []

    func refresh() {
        // 从 PluginVM 过滤出已启用的编辑器插件
        enabledPlugins = PluginVM.shared.plugins
            .filter { plugin in
                PluginVM.shared.isPluginEnabled(plugin) && plugin.providesEditorExtensions
            }
            .map { plugin in
                let type = type(of: plugin)
                return PluginInfo(
                    id: type.id,
                    displayName: type.displayName,
                    description: type.description
                )
            }
    }
}
