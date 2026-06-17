import LumiUI
import SwiftUI

struct ScreenshotsSection: View {
    @ObservedObject var viewModel: ConnectViewModel
    @Binding var importingScreenshots: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader

            devicePicker

            screenshotsContent
        }
    }

    private var sectionHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(AppStoreConnectLocalization.string("App Previews and Screenshots"))
                    .font(.title3.weight(.semibold))
                Text(AppStoreConnectLocalization.string("Manage screenshots for the selected locale and device size"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            AppButton(AppStoreConnectLocalization.string("Add Screenshots"), systemImage: "plus", size: .small) {
                importingScreenshots = true
            }
            .disabled(viewModel.selectedLocalizationID == nil)

            AppButton(AppStoreConnectLocalization.string("Ensure Screenshot Set"), systemImage: "folder.badge.plus", size: .small) {
                Task { await viewModel.ensureScreenshotSet() }
            }
            .disabled(viewModel.selectedLocalizationID == nil)
        }
        .padding(.horizontal)
    }

    private var devicePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.availableScreenshotDisplayTypes, id: \.self) { type in
                    let isSelected = viewModel.selectedScreenshotDisplayType == type
                    Button {
                        viewModel.selectedScreenshotDisplayType = type
                    } label: {
                        Text(ScreenshotDisplayFormatting.label(for: type))
                            .font(.caption.weight(isSelected ? .semibold : .regular))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(isSelected ? Color.accentColor.opacity(0.16) : Color.secondary.opacity(0.10), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private var screenshotsContent: some View {
        if viewModel.selectedLocalizationID == nil {
            emptyState(
                icon: "photo.on.rectangle.angled",
                title: AppStoreConnectLocalization.string("No Localization Selected"),
                description: AppStoreConnectLocalization.string("Load localizations for this version to manage screenshots.")
            )
        } else if let error = viewModel.errorMessage,
                  !hasScreenshotContent,
                  viewModel.screenshotSets.isEmpty {
            emptyState(
                icon: "exclamationmark.triangle",
                title: AppStoreConnectLocalization.string("Failed to Load Screenshot Sets"),
                description: error,
                actionTitle: AppStoreConnectLocalization.string("Refresh"),
                action: { Task { await viewModel.loadScreenshotSets(forceRefresh: true) } }
            )
        } else if viewModel.screenshotSets.isEmpty, !hasScreenshotContent {
            emptyState(
                icon: "photo.on.rectangle",
                title: AppStoreConnectLocalization.string("No Screenshot Sets"),
                description: AppStoreConnectLocalization.string("Load screenshot sets from App Store Connect, or ensure a set exists for the selected display type."),
                actionTitle: AppStoreConnectLocalization.string("Refresh"),
                action: { Task { await viewModel.loadScreenshotSets(forceRefresh: true) } }
            )
        } else if viewModel.selectedScreenshotSet == nil, !hasScreenshotContent {
            emptyState(
                icon: "photo.on.rectangle.angled",
                title: AppStoreConnectLocalization.string("No Screenshot Set for Display Type"),
                description: AppStoreConnectLocalization.string("Create a screenshot set for the selected display type, or switch to another device size."),
                actionTitle: AppStoreConnectLocalization.string("Ensure Screenshot Set"),
                action: { Task { await viewModel.ensureScreenshotSet() } }
            )
        } else if !hasScreenshotContent {
            emptyState(
                icon: "photo",
                title: AppStoreConnectLocalization.string("No Screenshots"),
                description: AppStoreConnectLocalization.string("This screenshot set is empty on App Store Connect. Add screenshots here or upload them in App Store Connect."),
                actionTitle: AppStoreConnectLocalization.string("Refresh"),
                action: { Task { await viewModel.reloadScreenshotsForSelectedDisplayType(forceRefresh: true) } }
            )
        } else {
            VStack(alignment: .leading, spacing: 12) {
                if let error = viewModel.errorMessage {
                    ErrorBanner(message: error)
                        .padding(.horizontal)
                }

                ScreenshotFilmstrip(
                    screenshots: viewModel.screenshots,
                    pendingScreenshots: viewModel.pendingScreenshots,
                    onRemovePending: { viewModel.removeScreenshot($0) }
                )
            }
        }
    }

    private var hasScreenshotContent: Bool {
        !viewModel.screenshots.isEmpty || !viewModel.pendingScreenshots.isEmpty
    }

    @ViewBuilder
    private func emptyState(
        icon: String,
        title: String,
        description: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) -> some View {
        if let actionTitle, let action {
            InlineEmptyState(
                icon: icon,
                title: title,
                description: description,
                actionTitle: actionTitle,
                action: action
            )
            .padding(.horizontal)
        } else {
            InlineEmptyState(
                icon: icon,
                title: title,
                description: description
            )
            .padding(.horizontal)
        }
    }
}

enum ScreenshotDisplayFormatting {
    static func label(for type: String) -> String {
        switch type {
        case "APP_IPHONE_67": return "6.7\" iPhone"
        case "APP_IPHONE_65": return "6.5\" iPhone"
        case "APP_IPHONE_61": return "6.1\" iPhone"
        case "APP_IPHONE_58": return "5.8\" iPhone"
        case "APP_IPAD_PRO_3GEN_129": return "12.9\" iPad"
        case "APP_IPAD_PRO_3GEN_11": return "11\" iPad"
        case "APP_DESKTOP": return "Mac"
        case "APP_APPLE_TV": return "Apple TV"
        default: return type
        }
    }
}
