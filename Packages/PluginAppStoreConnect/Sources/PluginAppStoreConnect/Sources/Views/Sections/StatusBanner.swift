import LumiUI
import SwiftUI

struct LocalizationOptionsView: View {
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
