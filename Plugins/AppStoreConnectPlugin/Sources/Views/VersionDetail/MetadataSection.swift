import LumiUI
import SwiftUI

struct MetadataSection: View {
    @ObservedObject var viewModel: ConnectViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(AppStoreConnectLocalization.string("Metadata"))
                    .font(.title3.weight(.semibold))
                Text(AppStoreConnectLocalization.string("Edit App Store version localization fields"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .appStoreConnectAddToChatMenu(
                entityType: "metadataSection",
                entityID: viewModel.selectedLocalizationID ?? "none",
                title: "Metadata",
                sourceView: "VersionDetail.MetadataSection",
                fields: [
                    "hasLocalizations": viewModel.localizations.isEmpty ? "false" : "true",
                    "selectedLocalizationID": viewModel.selectedLocalizationID ?? "-"
                ]
            )

            if viewModel.localizations.isEmpty {
                InlineEmptyState(
                    icon: "text.badge.xmark",
                    title: AppStoreConnectLocalization.string("No Localizations"),
                    description: AppStoreConnectLocalization.string("Select a version and refresh to load localizations.")
                )
                .padding(.horizontal)
                .appStoreConnectAddToChatMenu(
                    entityType: "metadataEmptyState",
                    entityID: "no-localizations",
                    title: "No Localizations",
                    sourceView: "VersionDetail.MetadataSection",
                    fields: [
                        "selectedVersionID": viewModel.selectedVersion?.id ?? "-",
                        "selectedVersionString": viewModel.selectedVersion?.versionString ?? "-"
                    ]
                )
            } else {
                MetadataEditor(viewModel: viewModel)
            }
        }
    }
}

struct MetadataEditor: View {
    @ObservedObject var viewModel: ConnectViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            field(AppStoreConnectLocalization.string("Promotional Text"), limit: 170, text: binding(\.promotionalText), axis: .vertical)
            field(AppStoreConnectLocalization.string("Description"), limit: 4000, text: binding(\.description), axis: .vertical, height: 120)
            field(AppStoreConnectLocalization.string("Keywords"), limit: 100, text: binding(\.keywords))
            field(AppStoreConnectLocalization.string("What's New"), limit: 4000, text: binding(\.whatsNew), axis: .vertical, height: 80)
            field(AppStoreConnectLocalization.string("Support URL"), limit: 255, text: binding(\.supportURL))
            field(AppStoreConnectLocalization.string("Marketing URL"), limit: 255, text: binding(\.marketingURL))
        }
        .disabled(viewModel.isMetadataReadOnly)
        .padding(.horizontal)
        .appStoreConnectAddToChatMenu(
            entityType: "metadataEditor",
            entityID: viewModel.editedLocalization?.id ?? viewModel.selectedLocalizationID ?? "none",
            title: viewModel.editedLocalization?.locale ?? "Metadata Editor",
            sourceView: "VersionDetail.MetadataEditor",
            fields: [
                "isDirty": viewModel.metadataIsDirty ? "true" : "false",
                "locale": viewModel.editedLocalization?.locale ?? "-"
            ]
        )
    }

    private func binding(_ keyPath: WritableKeyPath<AppStoreVersionLocalization, String>) -> Binding<String> {
        Binding(
            get: { viewModel.editedLocalization?[keyPath: keyPath] ?? "" },
            set: { newValue in
                viewModel.editedLocalization?[keyPath: keyPath] = newValue
                viewModel.markMetadataDirty()
            }
        )
    }

    private func field(
        _ title: String,
        limit: Int,
        text: Binding<String>,
        axis: Axis = .horizontal,
        height: CGFloat? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))
                Spacer()
                Text("\(text.wrappedValue.count)/\(limit)")
                    .font(.caption2)
                    .foregroundStyle(text.wrappedValue.count > limit ? .red : .secondary)
            }

            if axis == .vertical {
                TextEditor(text: text)
                    .font(.body)
                    .frame(minHeight: height ?? 72)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.22))
                    )
            } else {
                GlassTextField(title: title, text: text)
            }
        }
    }
}
