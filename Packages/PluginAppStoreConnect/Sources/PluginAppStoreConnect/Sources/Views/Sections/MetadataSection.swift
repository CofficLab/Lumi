import LumiUI
import SwiftUI

struct MetadataSection: View {
    @ObservedObject var viewModel: VM

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(AppStoreConnectLocalization.string("Metadata"))
                .font(.title3.weight(.semibold))
                .padding(.horizontal)
                .appStoreConnectAddToChatMenu(
                    entityType: "metadataSection",
                    entityID: viewModel.selectedLocalizationID ?? "none",
                    title: AppStoreConnectLocalization.string("Metadata"),
                    sourceView: "VersionDetail.MetadataSection",
                    fields: [
                        "hasLocalizations": viewModel.localizations.isEmpty ? "false" : "true",
                        "selectedLocalizationID": viewModel.selectedLocalizationID ?? "-",
                    ]
                )

            if viewModel.localizations.isEmpty {
                AppEmptyState(
                    icon: "text.badge.xmark",
                    title: AppStoreConnectLocalization.string("No Localizations"),
                    description: AppStoreConnectLocalization.string("Select a version and refresh to load localizations.")
                )
                .frame(minHeight: 160)
                .padding(.horizontal)
                .appStoreConnectAddToChatMenu(
                    entityType: "metadataEmptyState",
                    entityID: "no-localizations",
                    title: AppStoreConnectLocalization.string("No Localizations"),
                    sourceView: "VersionDetail.MetadataSection",
                    fields: [
                        "selectedVersionID": viewModel.selectedVersion?.id ?? "-",
                        "selectedVersionString": viewModel.selectedVersion?.versionString ?? "-",
                    ]
                )
            } else {
                MetadataEditor(viewModel: viewModel)
            }
        }
    }
}

struct MetadataEditor: View {
    @ObservedObject var viewModel: VM
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            field(AppStoreConnectLocalization.string("Promotional Text"), icon: "megaphone", limit: 170, text: binding(\.promotionalText), axis: .vertical)
            field(AppStoreConnectLocalization.string("Description"), icon: "doc.text", limit: 4000, text: binding(\.description), axis: .vertical, height: 120)
            field(AppStoreConnectLocalization.string("Keywords"), icon: "tag", limit: 100, text: binding(\.keywords))
            field(AppStoreConnectLocalization.string("What's New"), icon: "sparkles", limit: 4000, text: binding(\.whatsNew), axis: .vertical, height: 80)
            field(AppStoreConnectLocalization.string("Support URL"), icon: "lifepreserver", limit: 255, text: binding(\.supportURL), opensURL: true)
            field(AppStoreConnectLocalization.string("Marketing URL"), icon: "link", limit: 255, text: binding(\.marketingURL), opensURL: true)
        }
        .padding(.horizontal)
        .appStoreConnectAddToChatMenu(
            entityType: "metadataEditor",
            entityID: viewModel.editedLocalization?.id ?? viewModel.selectedLocalizationID ?? "none",
            title: viewModel.editedLocalization?.locale ?? "Metadata Editor",
            sourceView: "VersionDetail.MetadataEditor",
            fields: [
                "isDirty": viewModel.metadataIsDirty ? "true" : "false",
                "locale": viewModel.editedLocalization?.locale ?? "-",
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
        icon: String,
        limit: Int,
        text: Binding<String>,
        axis: Axis = .horizontal,
        height: CGFloat? = nil,
        opensURL: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                MetadataFieldLabel(title: title, systemImage: icon)
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
                HStack(spacing: 8) {
                    GlassTextField(title: "", text: text, placeholder: title)

                    if opensURL {
                        AppIconButton(systemImage: "arrow.up.right.square", tint: .accentColor) {
                            openURLValue(text.wrappedValue)
                        }
                        .help(AppStoreConnectLocalization.string("Open URL in Browser"))
                        .accessibilityLabel(AppStoreConnectLocalization.string("Open %@ in Browser", title))
                    }
                }
            }
        }
    }

    private func openURLValue(_ rawValue: String) {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: value),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              url.host != nil else {
            viewModel.errorMessage = AppStoreConnectLocalization.string(
                "Enter a valid http or https URL before opening it."
            )
            return
        }

        openURL(url)
    }
}
