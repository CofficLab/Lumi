import LumiUI
import SwiftUI

struct MetadataDisplaySection: View {
    let localization: AppStoreVersionLocalization?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(AppStoreConnectLocalization.string("Metadata"))
                .font(.title3.weight(.semibold))
                .padding(.horizontal)
                .appStoreConnectAddToChatMenu(
                    entityType: "metadataSection",
                    entityID: localization?.id ?? "none",
                    title: "Metadata",
                    sourceView: "VersionDetail.MetadataDisplaySection",
                    fields: [
                        "locale": localization?.locale ?? "-",
                    ]
                )

            if let localization {
                VStack(alignment: .leading, spacing: 14) {
                    readOnlyField(AppStoreConnectLocalization.string("Promotional Text"), value: localization.promotionalText)
                    readOnlyField(AppStoreConnectLocalization.string("Description"), value: localization.description)
                    readOnlyField(AppStoreConnectLocalization.string("Keywords"), value: localization.keywords)
                    readOnlyField(AppStoreConnectLocalization.string("What's New"), value: localization.whatsNew)
                    readOnlyURLField(AppStoreConnectLocalization.string("Support URL"), value: localization.supportURL)
                    readOnlyURLField(AppStoreConnectLocalization.string("Marketing URL"), value: localization.marketingURL)
                }
                .padding(.horizontal)
                .appStoreConnectAddToChatMenu(
                    entityType: "metadataDisplay",
                    entityID: localization.id,
                    title: localization.locale,
                    sourceView: "VersionDetail.MetadataDisplaySection",
                    fields: [
                        "locale": localization.locale,
                    ]
                )
            } else {
                InlineEmptyState(
                    icon: "text.badge.xmark",
                    title: AppStoreConnectLocalization.string("No Localizations"),
                    description: AppStoreConnectLocalization.string("Select a version and refresh to load localizations.")
                )
                .padding(.horizontal)
            }
        }
    }

    @ViewBuilder
    private func readOnlyField(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("—")
                    .font(.body)
                    .foregroundStyle(.tertiary)
            } else {
                Text(value)
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private func readOnlyURLField(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if let url = URL(string: value), !value.isEmpty {
                Link(value, destination: url)
                    .font(.body)
            } else if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("—")
                    .font(.body)
                    .foregroundStyle(.tertiary)
            } else {
                Text(value)
                    .font(.body)
                    .textSelection(.enabled)
            }
        }
    }
}
