import SwiftUI

struct HotPreviewToolbar: View {
    @EnvironmentObject private var themeVM: ThemeVM
    @ObservedObject var viewModel: EditorRemoteHotPreviewViewModel
    let currentFileURL: URL?
    let deleteStaleStringCatalogEntries: () -> Void

    private var toolbarIcon: String {
        if viewModel.isImageMode {
            return "photo"
        } else if viewModel.isMarkdownMode {
            return "doc.richtext"
        } else if viewModel.isStringCatalogMode {
            return "character.book.closed"
        }
        return "bolt.horizontal"
    }

    private var toolbarTitle: String {
        if viewModel.isImageMode {
            return String(localized: "Image Preview", table: "EditorPreview")
        } else if viewModel.isMarkdownMode {
            return String(localized: "Markdown Preview", table: "EditorPreview")
        } else if viewModel.isStringCatalogMode {
            return String(localized: "String Catalog Preview", table: "EditorPreview")
        }
        return String(localized: "V2", table: "EditorPreview")
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: toolbarIcon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())

            if let currentFileURL {
                Text(currentFileURL.lastPathComponent)
                    .font(.system(size: 11))
                    .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if viewModel.isStringCatalogMode {
                Button {
                    deleteStaleStringCatalogEntries()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(viewModel.staleStringCatalogEntryCount > 0
                            ? .orange
                            : themeVM.activeAppTheme.workspaceTertiaryTextColor().opacity(0.6))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.staleStringCatalogEntryCount == 0)
                .help(
                    viewModel.staleStringCatalogEntryCount > 0
                        ? String(
                            format: String(localized: "Delete %lld stale string catalog entries", table: "EditorPreview"),
                            Int64(viewModel.staleStringCatalogEntryCount)
                        )
                        : String(localized: "No stale string catalog entries", table: "EditorPreview")
                )
            } else if !viewModel.isImageMode, !viewModel.isMarkdownMode {
                if let updateTitle = viewModel.updatePhase.title {
                    updateBadge(updateTitle)
                }

                HotPreviewDisplayModePickerView(viewModel: viewModel)
                statusBadge

                Button {
                    viewModel.startHost()
                } label: {
                    Image(systemName: "play.fill")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.canStart)
                .help(String(localized: "Start hot preview", table: "EditorPreview"))

                Button {
                    viewModel.renderFrame()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.hostState == .idle)
                .help(String(localized: "Refresh hot preview", table: "EditorPreview"))

                Button {
                    viewModel.stopHost()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.canStop)
                .help(String(localized: "Stop hot preview", table: "EditorPreview"))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 38, maxHeight: 38, alignment: .leading)
        .padding(.horizontal, 12)
        .background(themeVM.activeAppTheme.workspaceTertiaryTextColor().opacity(0.05))
    }

    // MARK: - 子视图

    private var statusBadge: some View {
        let statusColor = Self.statusColor(for: viewModel.hostState, theme: themeVM.activeAppTheme)
        return HStack(spacing: 5) {
            Circle()
                .fill(statusColor)
                .frame(width: 7, height: 7)
            Text(viewModel.hostState.title)
                .lineLimit(1)
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundColor(statusColor)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(statusColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 5))
    }

    private func updateBadge(_ title: String) -> some View {
        HStack(spacing: 5) {
            ProgressView()
                .controlSize(.small)
                .scaleEffect(0.55)
                .frame(width: 10, height: 10)
            Text(title)
                .lineLimit(1)
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundColor(.orange)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Color.orange.opacity(0.14), in: RoundedRectangle(cornerRadius: 5))
    }

    // MARK: - 私有方法

    private static func statusColor(
        for hostState: EditorRemoteHotPreviewHostState,
        theme: any SuperTheme
    ) -> Color {
        switch hostState {
        case .idle:
            return theme.workspaceSecondaryTextColor().opacity(0.7)
        case .launching, .rendering:
            return .orange
        case .connected:
            return .green
        case .failed:
            return .red
        }
    }
}

private struct HotPreviewDisplayModePickerView: View {
    @EnvironmentObject private var themeVM: ThemeVM
    @ObservedObject var viewModel: EditorRemoteHotPreviewViewModel

    var body: some View {
        HStack(spacing: 0) {
            Button {
                viewModel.switchToImage()
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "photo")
                        .font(.system(size: 9, weight: .medium))
                    Text(String(localized: "Image", table: "EditorPreview"))
                        .font(.system(size: 10, weight: .medium))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    viewModel.preferredDisplayMode == .image
                        ? themeVM.activeAppTheme.workspaceTextColor().opacity(0.12)
                        : Color.clear
                )
                .foregroundColor(
                    viewModel.preferredDisplayMode == .image
                        ? themeVM.activeAppTheme.workspaceTextColor()
                        : themeVM.activeAppTheme.workspaceSecondaryTextColor()
                )
            }
            .buttonStyle(.plain)

            Rectangle()
                .fill(themeVM.activeAppTheme.workspaceTertiaryTextColor().opacity(0.2))
                .frame(width: 1, height: 14)

            Button {
                if viewModel.canSwitchToLive || viewModel.preferredDisplayMode != .live {
                    viewModel.switchToLive()
                }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: viewModel.preferredDisplayMode == .live ? "play.rectangle.fill" : "play.rectangle")
                        .font(.system(size: 9, weight: .medium))
                    Text(String(localized: "Live", table: "EditorPreview"))
                        .font(.system(size: 10, weight: .medium))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    viewModel.preferredDisplayMode == .live
                        ? themeVM.activeAppTheme.workspaceTextColor().opacity(0.12)
                        : Color.clear
                )
                .foregroundColor(liveTabColor)
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canSwitchToLive && viewModel.preferredDisplayMode != .live)
            .help(viewModel.liveUnavailableReason ?? String(localized: "Switch to Live mode", table: "EditorPreview"))
        }
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(themeVM.activeAppTheme.workspaceTertiaryTextColor().opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(themeVM.activeAppTheme.workspaceTertiaryTextColor().opacity(0.15), lineWidth: 0.5)
        )
    }

    private var liveTabColor: Color {
        if viewModel.preferredDisplayMode == .live {
            return .green
        }
        if viewModel.canSwitchToLive {
            return themeVM.activeAppTheme.workspaceSecondaryTextColor()
        }
        return themeVM.activeAppTheme.workspaceTertiaryTextColor().opacity(0.5)
    }
}
