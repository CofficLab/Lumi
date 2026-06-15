import LumiUI
import SwiftUI

struct MetadataPage: View {
    @ObservedObject var viewModel: AppStoreConnectViewModel

    var body: some View {
        VStack(spacing: 0) {
            PageHeader(
                title: AppStoreConnectLocalization.string("Metadata"),
                subtitle: AppStoreConnectLocalization.string("Edit App Store version localization fields")
            )

            if viewModel.localizations.isEmpty {
                AppEmptyState(
                    icon: "text.badge.xmark",
                    title: AppStoreConnectLocalization.string("No Localizations"),
                    description: AppStoreConnectLocalization.string("Select a version and refresh metadata to load localizations.")
                )
            } else {
                HStack {
                    Picker(AppStoreConnectLocalization.string("Locale"), selection: Binding(
                        get: { viewModel.selectedLocalizationID ?? "" },
                        set: { viewModel.selectLocalization(id: $0) }
                    )) {
                        ForEach(viewModel.localizations) { localization in
                            Text(localization.locale).tag(localization.id)
                        }
                    }
                    .frame(width: 220)

                    Spacer()

                    if viewModel.metadataIsDirty {
                        Text(AppStoreConnectLocalization.string("Unsaved changes"))
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                    AppButton(AppStoreConnectLocalization.string("Save Metadata"), systemImage: "square.and.arrow.down", style: .primary, size: .small) {
                        Task { await viewModel.saveMetadata() }
                    }
                    .disabled(!viewModel.metadataIsDirty)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)

                MetadataEditor(viewModel: viewModel)
            }
        }
    }
}

struct MetadataEditor: View {
    @ObservedObject var viewModel: AppStoreConnectViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                field(AppStoreConnectLocalization.string("Promotional Text"), limit: 170, text: binding(\.promotionalText), axis: .vertical)
                field(AppStoreConnectLocalization.string("Description"), limit: 4000, text: binding(\.description), axis: .vertical, height: 160)
                field(AppStoreConnectLocalization.string("Keywords"), limit: 100, text: binding(\.keywords))
                field(AppStoreConnectLocalization.string("What's New"), limit: 4000, text: binding(\.whatsNew), axis: .vertical, height: 120)
                field(AppStoreConnectLocalization.string("Support URL"), limit: 255, text: binding(\.supportURL))
                field(AppStoreConnectLocalization.string("Marketing URL"), limit: 255, text: binding(\.marketingURL))
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
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
