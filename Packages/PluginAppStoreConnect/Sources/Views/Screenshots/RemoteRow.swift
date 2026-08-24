import LumiUI
import SwiftUI

struct RemoteScreenshotRow: View {
    let screenshot: AppScreenshot

    var body: some View {
        AppListRow {
            HStack(spacing: 12) {
                screenshotThumbnail

                VStack(alignment: .leading, spacing: 3) {
                    Text(screenshot.fileName.isEmpty ? screenshot.id : screenshot.fileName)
                        .font(.body.weight(.medium))
                        .lineLimit(1)
                    if let fileSize = screenshot.fileSize {
                        Text(ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Label(AppStoreConnectLocalization.string("On App Store Connect"), systemImage: "icloud")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .appStoreConnectAddToChatMenu(
            entityType: "screenshot",
            entityID: screenshot.id,
            title: screenshot.fileName.isEmpty ? screenshot.id : screenshot.fileName,
            sourceView: "RemoteScreenshotRow",
            fields: [
                "fileSize": screenshot.fileSize.map(String.init) ?? "-",
                "previewURL": screenshot.previewURL?.absoluteString ?? "-"
            ]
        )
    }

    @ViewBuilder
    private var screenshotThumbnail: some View {
        if let previewURL = screenshot.previewURL {
            CachedScreenshotThumbnail(url: previewURL, screenshotID: screenshot.id, contentMode: .fill) {
                ProgressView().controlSize(.small)
            } failure: {
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        } else {
            Image(systemName: "photo")
                .font(.title3)
                .frame(width: 44, height: 44)
        }
    }
}
