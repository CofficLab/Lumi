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
                if !viewModel.localizations.isEmpty {
                    Picker(AppStoreConnectLocalization.string("Locale"), selection: Binding(
                        get: { viewModel.selectedLocalizationID ?? "" },
                        set: { viewModel.selectLocalization(id: $0) }
                    )) {
                        ForEach(viewModel.localizations) { localization in
                            Text(localization.locale).tag(localization.id)
                        }
                    }
                    .frame(width: 180)
                }

                Picker(AppStoreConnectLocalization.string("Display"), selection: $viewModel.selectedScreenshotDisplayType) {
                    ForEach(viewModel.availableScreenshotDisplayTypes, id: \.self) { type in
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
        .onChange(of: viewModel.selectedScreenshotDisplayType) { _, _ in
            Task { await viewModel.reloadScreenshotsForSelectedDisplayType() }
        }
    }

    private var hasScreenshotContent: Bool {
        !viewModel.screenshots.isEmpty || !viewModel.pendingScreenshots.isEmpty
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
                  !hasScreenshotContent,
                  viewModel.screenshotSets.isEmpty {
            AppEmptyState(
                icon: "exclamationmark.triangle",
                title: AppStoreConnectLocalization.string("Failed to Load Screenshot Sets"),
                description: error,
                actionTitle: AppStoreConnectLocalization.string("Refresh"),
                action: { Task { await viewModel.loadScreenshotSets() } }
            )
        } else if viewModel.screenshotSets.isEmpty, !hasScreenshotContent {
            AppEmptyState(
                icon: "photo.on.rectangle",
                title: AppStoreConnectLocalization.string("No Screenshot Sets"),
                description: AppStoreConnectLocalization.string("Load screenshot sets from App Store Connect, or ensure a set exists for the selected display type."),
                actionTitle: AppStoreConnectLocalization.string("Refresh"),
                action: { Task { await viewModel.loadScreenshotSets() } }
            )
        } else if viewModel.selectedScreenshotSet == nil, !hasScreenshotContent {
            AppEmptyState(
                icon: "photo.on.rectangle.angled",
                title: AppStoreConnectLocalization.string("No Screenshot Set for Display Type"),
                description: AppStoreConnectLocalization.string("Create a screenshot set for the selected display type, or switch to another device size."),
                actionTitle: AppStoreConnectLocalization.string("Ensure Screenshot Set"),
                action: { Task { await viewModel.ensureScreenshotSet() } }
            )
        } else if !hasScreenshotContent {
            AppEmptyState(
                icon: "photo",
                title: AppStoreConnectLocalization.string("No Screenshots"),
                description: AppStoreConnectLocalization.string("This screenshot set is empty on App Store Connect. Add screenshots here or upload them in App Store Connect."),
                actionTitle: AppStoreConnectLocalization.string("Refresh"),
                action: { Task { await viewModel.reloadScreenshotsForSelectedDisplayType() } }
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
                    if !viewModel.screenshots.isEmpty {
                        Section(AppStoreConnectLocalization.string("App Store Connect")) {
                            ForEach(viewModel.screenshots) { screenshot in
                                RemoteScreenshotRow(screenshot: screenshot)
                            }
                        }
                    }

                    if !viewModel.pendingScreenshots.isEmpty {
                        Section(AppStoreConnectLocalization.string("Pending Upload")) {
                            ForEach(viewModel.pendingScreenshots) { screenshot in
                                PendingScreenshotRow(screenshot: screenshot) {
                                    viewModel.removeScreenshot(screenshot)
                                }
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
    }
}
