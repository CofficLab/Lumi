import LumiUI
import SwiftUI

struct ScreenshotsPage: View {
    @ObservedObject var viewModel: AppStoreConnectViewModel
    @Binding var importingScreenshots: Bool

    var body: some View {
        VStack(spacing: 0) {
            PageHeader(
                title: AppStoreConnectLocalization.string("Screenshots"),
                subtitle: AppStoreConnectLocalization.string("Validate and prepare screenshots for the selected localization")
            )

            HStack {
                Picker(AppStoreConnectLocalization.string("Display"), selection: $viewModel.selectedScreenshotDisplayType) {
                    ForEach(viewModel.screenshotDisplayTypes, id: \.self) { type in
                        Text(type).tag(type)
                    }
                }
                .frame(width: 260)

                AppButton(AppStoreConnectLocalization.string("Add Screenshots"), systemImage: "plus", size: .small) {
                    importingScreenshots = true
                }
                .disabled(viewModel.selectedLocalizationID == nil)

                AppButton(AppStoreConnectLocalization.string("Ensure Screenshot Set"), systemImage: "folder.badge.plus", size: .small) {
                    Task { await viewModel.ensureScreenshotSet() }
                }
                .disabled(viewModel.selectedLocalizationID == nil)

                Spacer()
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

            screenshotsMainContent
        }
    }

    @ViewBuilder
    private var screenshotsMainContent: some View {
        if viewModel.selectedLocalizationID == nil {
            AppEmptyState(
                icon: "photo.on.rectangle.angled",
                title: AppStoreConnectLocalization.string("No Localization Selected"),
                description: AppStoreConnectLocalization.string("Select a version and load metadata before managing screenshots.")
            )
        } else if let error = viewModel.errorMessage,
                  viewModel.screenshotSets.isEmpty,
                  viewModel.pendingScreenshots.isEmpty {
            AppEmptyState(
                icon: "exclamationmark.triangle",
                title: AppStoreConnectLocalization.string("Failed to Load Screenshot Sets"),
                description: error,
                actionTitle: AppStoreConnectLocalization.string("Refresh"),
                action: { Task { await viewModel.loadScreenshotSets() } }
            )
        } else if viewModel.screenshotSets.isEmpty, viewModel.pendingScreenshots.isEmpty {
            AppEmptyState(
                icon: "photo.on.rectangle",
                title: AppStoreConnectLocalization.string("No Screenshot Sets"),
                description: AppStoreConnectLocalization.string("Load screenshot sets from App Store Connect, or ensure a set exists for the selected display type."),
                actionTitle: AppStoreConnectLocalization.string("Refresh"),
                action: { Task { await viewModel.loadScreenshotSets() } }
            )
        } else {
            VStack(spacing: 0) {
                if let error = viewModel.errorMessage {
                    AppCard(style: .subtle, cornerRadius: 8, showShadow: false) {
                        VStack(alignment: .leading, spacing: 10) {
                            ErrorBanner(message: error)
                            HStack {
                                Spacer()
                                AppButton(AppStoreConnectLocalization.string("Refresh"), systemImage: "arrow.clockwise", size: .small) {
                                    Task { await viewModel.loadScreenshotSets() }
                                }
                                .disabled(viewModel.isBusy)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }

                ScreenshotSetSummary(sets: viewModel.screenshotSets)

                List {
                    ForEach(viewModel.pendingScreenshots) { screenshot in
                        PendingScreenshotRow(screenshot: screenshot) {
                            viewModel.removeScreenshot(screenshot)
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
    }
}

struct ScreenshotSetSummary: View {
    let sets: [ScreenshotSet]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                if sets.isEmpty {
                    Text(AppStoreConnectLocalization.string("No screenshot sets loaded"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sets) { set in
                        Text(set.screenshotDisplayType)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.12), in: Capsule())
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }
}

struct PendingScreenshotRow: View {
    let screenshot: PendingScreenshot
    let onRemove: () -> Void

    var body: some View {
        AppListRow {
            HStack(spacing: 12) {
                Image(systemName: "photo")
                    .font(.title3)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 3) {
                    Text(screenshot.fileName)
                        .font(.body.weight(.medium))
                        .lineLimit(1)
                    Text("\(screenshot.width) x \(screenshot.height) · \(screenshot.displayType)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                status

                AppIconButton(systemImage: "trash", tint: .red, action: onRemove)
            }
        }
    }

    @ViewBuilder
    private var status: some View {
        switch screenshot.status {
        case .ready:
            Label(AppStoreConnectLocalization.string("Ready"), systemImage: "checkmark.circle")
                .foregroundStyle(.green)
        case .invalid(let message):
            Label(message, systemImage: "xmark.octagon")
                .foregroundStyle(.red)
        case .uploading:
            Label(AppStoreConnectLocalization.string("Uploading"), systemImage: "arrow.up.circle")
                .foregroundStyle(.secondary)
        case .uploaded:
            Label(AppStoreConnectLocalization.string("Uploaded"), systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.red)
        }
    }
}
