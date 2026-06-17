import LumiUI
import SwiftUI

struct VersionStatusBanner: View {
    let version: AppStoreVersion

    var body: some View {
        AppCard(style: .subtle, cornerRadius: 10, showShadow: false) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(AppStoreConnectLocalization.string("Version %@", version.versionString))
                        .font(.headline)
                    Text(version.appStoreState.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let createdDate = version.createdDate {
                    Text(ViewFormatting.dateTimeFormatter.string(from: createdDate))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(version.platform)
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.12), in: Capsule())
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
        .padding(.horizontal)
        .padding(.top, 12)
    }
}
