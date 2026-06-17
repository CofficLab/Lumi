import LumiUI
import SwiftUI

struct ScreenshotFilmstrip: View {
    let screenshots: [AppScreenshot]
    let pendingScreenshots: [PendingScreenshot]
    let onRemovePending: (PendingScreenshot) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(screenshots) { screenshot in
                    FilmstripRemoteCard(screenshot: screenshot)
                }

                ForEach(pendingScreenshots) { screenshot in
                    FilmstripPendingCard(screenshot: screenshot, onRemove: { onRemovePending(screenshot) })
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
        }
        .frame(height: 180)
    }
}

private struct FilmstripRemoteCard: View {
    let screenshot: AppScreenshot

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            thumbnail
                .frame(width: 120, height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.secondary.opacity(0.2))
                )

            Text(screenshot.fileName.isEmpty ? screenshot.id : screenshot.fileName)
                .font(.caption2)
                .lineLimit(1)
                .frame(width: 120, alignment: .leading)

            Label(AppStoreConnectLocalization.string("On App Store Connect"), systemImage: "icloud")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .appStoreConnectAddToChatMenu(
            entityType: "screenshot",
            entityID: screenshot.id,
            title: screenshot.fileName.isEmpty ? screenshot.id : screenshot.fileName,
            sourceView: "ScreenshotFilmstrip",
            fields: [
                "fileSize": screenshot.fileSize.map(String.init) ?? "-",
                "previewURL": screenshot.previewURL?.absoluteString ?? "-"
            ]
        )
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let previewURL = screenshot.previewURL {
            AsyncImage(url: previewURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .empty:
                    ProgressView().controlSize(.small)
                default:
                    placeholder
                }
            }
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        Image(systemName: "photo")
            .font(.title2)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.secondary.opacity(0.08))
    }
}

private struct FilmstripPendingCard: View {
    let screenshot: PendingScreenshot
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.secondary.opacity(0.08))
                    .frame(width: 120, height: 160)
                    .overlay {
                        Image(systemName: "photo")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }

                AppIconButton(systemImage: "xmark", tint: .secondary, action: onRemove)
                    .padding(4)
            }

            Text(screenshot.fileName)
                .font(.caption2)
                .lineLimit(1)
                .frame(width: 120, alignment: .leading)

            Text(pendingStatusLabel)
                .font(.caption2)
                .foregroundStyle(pendingStatusColor)
                .lineLimit(2)
                .frame(width: 120, alignment: .leading)
        }
        .appStoreConnectAddToChatMenu(
            entityType: "pendingScreenshot",
            entityID: screenshot.id.uuidString,
            title: screenshot.fileName,
            sourceView: "ScreenshotFilmstrip",
            fields: [
                "displayType": screenshot.displayType,
                "height": String(screenshot.height),
                "width": String(screenshot.width)
            ]
        )
    }

    private var pendingStatusLabel: String {
        switch screenshot.status {
        case .ready: return AppStoreConnectLocalization.string("Ready")
        case .invalid(let message): return message
        case .uploading: return AppStoreConnectLocalization.string("Uploading")
        case .uploaded: return AppStoreConnectLocalization.string("Uploaded")
        case .failed(let message): return message
        }
    }

    private var pendingStatusColor: Color {
        switch screenshot.status {
        case .ready, .uploaded: return .green
        case .invalid, .failed: return .red
        case .uploading: return .secondary
        }
    }
}
