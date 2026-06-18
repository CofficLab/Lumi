import LumiUI
import SwiftUI

struct AppRow: View {
    let app: AppStoreApp

    var body: some View {
        AppListRow {
            HStack(spacing: 12) {
                IconView(url: app.iconURL)
                VStack(alignment: .leading, spacing: 3) {
                    Text(app.name)
                        .font(.body.weight(.medium))
                    Text(app.bundleID)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(app.sku)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(app.primaryLocale)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 70, alignment: .trailing)
                Text(app.platform)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 60, alignment: .trailing)
            }
        }
        .appStoreConnectAddToChatMenu(
            entityType: "app",
            entityID: app.id,
            title: app.name,
            sourceView: "AppsPage",
            fields: [
                "bundleID": app.bundleID,
                "platform": app.platform,
                "primaryLocale": app.primaryLocale,
                "sku": app.sku
            ]
        )
    }
}
