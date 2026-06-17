import AppKit
import LumiUI
import SwiftUI

enum ViewFormatting {
    static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

struct PageHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.title3.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
    }
}

struct InlineEmptyState: View {
    let icon: String
    let title: String
    let description: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.secondary)

            Text(title)
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)

            Text(description)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            if let actionTitle, let action {
                AppButton(actionTitle, style: .secondary, size: .small, action: action)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

struct ErrorBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            AppErrorBanner(message: LocalizedStringKey(message))

            AppButton(AppStoreConnectLocalization.string("Copy"), systemImage: "doc.on.doc", size: .small) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(message, forType: .string)
            }
        }
    }
}

struct IconView: View {
    let url: URL?
    var size: CGFloat = 34

    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .empty:
                        ProgressView()
                            .controlSize(.small)
                    case .failure:
                        fallback
                    @unknown default:
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: min(8, size * 0.24), style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: min(8, size * 0.24), style: .continuous)
                .stroke(Color.secondary.opacity(0.16))
        )
    }

    private var fallback: some View {
        Image(systemName: "app.dashed")
            .font(.system(size: size * 0.52, weight: .regular))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.secondary.opacity(0.08))
    }
}

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

struct VersionRow: View {
    let version: AppStoreVersion

    var body: some View {
        AppListRow {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(version.versionString)
                        .font(.body.weight(.medium))
                    Text(version.appVersionState)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(version.platform)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(version.appStoreState)
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.accentColor.opacity(0.12), in: Capsule())
            }
        }
        .appStoreConnectAddToChatMenu(
            entityType: "version",
            entityID: version.id,
            title: version.versionString,
            sourceView: "VersionRow",
            fields: [
                "appStoreState": version.appStoreState,
                "appVersionState": version.appVersionState,
                "platform": version.platform
            ]
        )
    }
}
