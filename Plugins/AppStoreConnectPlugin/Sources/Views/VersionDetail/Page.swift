import LumiUI
import SwiftUI

struct DistributionPage: View {
    @ObservedObject var viewModel: ConnectViewModel
    @Binding var importingScreenshots: Bool

    var body: some View {
        Group {
            if viewModel.selectedApp == nil {
                AppEmptyState(
                    icon: "square.grid.2x2",
                    title: AppStoreConnectLocalization.string("No App Selected"),
                    description: AppStoreConnectLocalization.string("Select an app from the Apps page or toolbar picker.")
                )
            } else if viewModel.selectedVersion == nil {
                AppEmptyState(
                    icon: "number",
                    title: AppStoreConnectLocalization.string("No Version Selected"),
                    description: AppStoreConnectLocalization.string("Choose a version from the sidebar to manage distribution.")
                )
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VersionStatusBanner(version: viewModel.selectedVersion!)

                        localePicker

                        ScreenshotsSection(
                            viewModel: viewModel,
                            importingScreenshots: $importingScreenshots
                        )

                        MetadataSection(viewModel: viewModel)
                    }
                    .padding(.bottom, 24)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: viewModel.selectedScreenshotDisplayType) { _, _ in
            Task { await viewModel.reloadScreenshotsForSelectedDisplayType() }
        }
    }

    @ViewBuilder
    private var localePicker: some View {
        if !viewModel.localizations.isEmpty {
            HStack {
                Text(AppStoreConnectLocalization.string("Locale"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Picker("", selection: Binding(
                    get: { viewModel.selectedLocalizationID ?? "" },
                    set: { viewModel.selectLocalization(id: $0) }
                )) {
                    ForEach(viewModel.localizations) { localization in
                        Text(localization.locale).tag(localization.id)
                    }
                }
                .labelsHidden()
                .frame(width: 200)

                Spacer()
            }
            .padding(.horizontal)
            .appStoreConnectAddToChatMenu(
                entityType: "localization",
                entityID: viewModel.selectedLocalizationID ?? "none",
                title: viewModel.selectedLocalization?.locale ?? "None",
                sourceView: "DistributionPage.localePicker",
                fields: [
                    "availableCount": String(viewModel.localizations.count),
                    "selectedLocale": viewModel.selectedLocalization?.locale ?? "-"
                ]
            )
        }
    }
}
