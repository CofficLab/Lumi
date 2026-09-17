import LumiUI
import SwiftUI

struct VersionActionsBar: View {
    let version: AppStoreVersion
    @ObservedObject var viewModel: VM
    let localePickerSourceView: String
    var embedded = false
    @State private var showsReleaseConfirmation = false
    @State private var showsSubmitConfirmation = false
    @State private var showsWithdrawConfirmation = false

    private let toolbarPadding = EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)

    private var content: some View {
        HStack(spacing: 16) {
            if !viewModel.localizations.isEmpty {
                ToolbarSelectControl(
                    title: viewModel.selectedLocalization?.locale
                        ?? AppStoreConnectLocalization.string("Locale"),
                    systemImage: "globe",
                    maxTitleWidth: 120
                ) {
                    LocalizationOptionsView(viewModel: viewModel)
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

            if version.isSubmittable {
                AppButton(
                    AppStoreConnectLocalization.string("Submit for Review"),
                    systemImage: "paperplane.fill",
                    style: .primary,
                    size: .small
                ) {
                    showsSubmitConfirmation = true
                }
                .disabled(viewModel.isBusy || viewModel.assignedBuildID == nil)
                .help(viewModel.assignedBuildID == nil
                    ? AppStoreConnectLocalization.string("Assign a build before submitting for review.")
                    : AppStoreConnectLocalization.string("Submit this version to App Review."))
            }

            if viewModel.submissionID != nil {
                AppButton(
                    AppStoreConnectLocalization.string("Withdraw Submission"),
                    systemImage: "arrow.uturn.backward.circle",
                    style: .secondary,
                    size: .small
                ) {
                    showsWithdrawConfirmation = true
                }
                .disabled(viewModel.isBusy)
            }

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

        }
    }

    var body: some View {
        Group {
            if embedded {
                content
            } else {
                AppToolbarContainer(padding: toolbarPadding) {
                    content
                }
            }
        }
        .appStoreConnectAddToChatMenu(
            entityType: "versionActionsBar",
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
        .confirmationDialog(
            AppStoreConnectLocalization.string("Submit for Review"),
            isPresented: $showsSubmitConfirmation,
            titleVisibility: .visible
        ) {
            Button(AppStoreConnectLocalization.string("Submit"), role: .destructive) {
                Task { await viewModel.submitForReview() }
            }
            Button(AppStoreConnectLocalization.string("Cancel"), role: .cancel) {}
        } message: {
            Text(AppStoreConnectLocalization.string(
                "Submit version %@ to App Review? Make sure the build, metadata, and screenshots are complete.",
                version.versionString
            ))
        }
        .confirmationDialog(
            AppStoreConnectLocalization.string("Withdraw Submission"),
            isPresented: $showsWithdrawConfirmation,
            titleVisibility: .visible
        ) {
            Button(AppStoreConnectLocalization.string("Withdraw"), role: .destructive) {
                Task { await viewModel.withdrawSubmission() }
            }
            Button(AppStoreConnectLocalization.string("Cancel"), role: .cancel) {}
        } message: {
            Text(AppStoreConnectLocalization.string(
                "Withdraw the review submission for version %@? You can submit again later.",
                version.versionString
            ))
        }
    }
}

private struct LocalizationOptionsView: View {
    @ObservedObject var viewModel: VM
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(AppStoreConnectLocalization.string("Locale"))
                .font(.headline)

            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(viewModel.localizations) { localization in
                        Button {
                            viewModel.selectLocalization(id: localization.id)
                            dismiss()
                        } label: {
                            HStack(spacing: 8) {
                                Text(localeIcon(for: localization.locale))
                                    .font(.system(size: 15))
                                    .frame(width: 22)

                                Text(localization.locale)
                                    .font(.system(size: 13, weight: .medium))
                                Spacer()
                                if viewModel.selectedLocalizationID == localization.id {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(.tint)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 7)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                viewModel.selectedLocalizationID == localization.id
                                    ? Color.accentColor.opacity(0.12)
                                    : Color.clear,
                                in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(width: 220)
            .frame(maxHeight: 280)
        }
    }

    private func localeIcon(for locale: String) -> String {
        let normalized = locale.lowercased()
        switch normalized {
        case let value where value.hasPrefix("zh"):
            return "🇨🇳"
        case let value where value.hasPrefix("en"):
            return "🇺🇸"
        case let value where value.hasPrefix("ja"):
            return "🇯🇵"
        case let value where value.hasPrefix("ko"):
            return "🇰🇷"
        case let value where value.hasPrefix("fr"):
            return "🇫🇷"
        case let value where value.hasPrefix("de"):
            return "🇩🇪"
        case let value where value.hasPrefix("es"):
            return "🇪🇸"
        case let value where value.hasPrefix("it"):
            return "🇮🇹"
        case let value where value.hasPrefix("pt"):
            return "🇵🇹"
        case let value where value.hasPrefix("ru"):
            return "🇷🇺"
        default:
            return "🌐"
        }
    }
}

/// 版本详情顶部的摘要信息，保持在主要内容区域中可见。
struct VersionOverviewView: View {
    let version: AppStoreVersion

    private let cardPadding = EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)

    var body: some View {
        AppCard(
            style: .subtle,
            cornerRadius: 8,
            padding: cardPadding,
            showShadow: false,
        ) {
            HStack(spacing: 12) {
                Image(systemName: "shippingbox.fill")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text(AppStoreConnectLocalization.string("Version status"))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(version.localizedAppStoreStateLabel)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.12), in: Capsule())
                }

                Spacer(minLength: 16)

                if let createdDate = version.createdDate {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(AppStoreConnectLocalization.string("Created"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(ViewFormatting.formatDateTime(createdDate))
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 4)
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
    }
}
