import LumiUI
import SwiftUI

struct VersionStatusBanner: View {
    let version: AppStoreVersion
    @ObservedObject var viewModel: VM
    let localePickerSourceView: String
    @State private var showsReleaseConfirmation = false

    private let toolbarPadding = EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)

    var body: some View {
        AppToolbarContainer(padding: toolbarPadding) {
            HStack(spacing: 16) {
                HStack(spacing: 8) {
                    Text(AppStoreConnectLocalization.string("Version %@", version.versionString))
                        .font(.callout.weight(.semibold))
                    Text(version.localizedAppStoreStateLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !viewModel.localizations.isEmpty {
                    HStack(spacing: 8) {
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
                        .frame(width: 160)
                    }
                    .appStoreConnectAddToChatMenu(
                        entityType: "localization",
                        entityID: viewModel.selectedLocalizationID ?? "none",
                        title: viewModel.selectedLocalization?.locale ?? "None",
                        sourceView: localePickerSourceView,
                        fields: [
                            "availableCount": String(viewModel.localizations.count),
                            "selectedLocale": viewModel.selectedLocalization?.locale ?? "-"
                        ]
                    )
                }

                Spacer()

                if version.isPendingDeveloperRelease {
                    AppButton(
                        AppStoreConnectLocalization.string("Release to App Store"),
                        systemImage: "arrow.up.circle.fill",
                        style: .primary,
                        size: .small
                    ) {
                        showsReleaseConfirmation = true
                    }
                    .disabled(viewModel.isBusy)
                }

                if let createdDate = version.createdDate {
                    Text(ViewFormatting.formatDateTime(createdDate))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .appStoreConnectAddToChatMenu(
            entityType: "versionStatusBanner",
            entityID: version.id,
            title: version.versionString,
            sourceView: "VersionDetail.StatusBanner",
            fields: [
                "appStoreState": version.appStoreState,
                "platform": version.platform
            ]
        )
        .confirmationDialog(
            AppStoreConnectLocalization.string("Release Version"),
            isPresented: $showsReleaseConfirmation,
            titleVisibility: .visible
        ) {
            Button(AppStoreConnectLocalization.string("Release"), role: .destructive) {
                Task { await viewModel.releaseVersion(version) }
            }
            Button(AppStoreConnectLocalization.string("Cancel"), role: .cancel) {}
        } message: {
            Text(AppStoreConnectLocalization.string(
                "Release %@ to the App Store? This action cannot be undone via the API.",
                version.versionString
            ))
        }
    }
}
