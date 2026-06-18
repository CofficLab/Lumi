import LumiUI
import SwiftUI

// MARK: - Filmstrip Layout

/// Computes card dimensions and filmstrip height based on the screenshot display type.
/// - Portrait devices (iPhone / iPad) use a 3:4 ratio.
/// - Mac (APP_DESKTOP) uses a 16:10 landscape ratio.
/// - Apple TV (APP_APPLE_TV) uses a 16:9 landscape ratio.
struct FilmstripLayout {
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    let filmstripHeight: CGFloat

    static func make(for displayType: String) -> FilmstripLayout {
        switch displayType {
        case "APP_DESKTOP":
            // Mac: 16:10 landscape
            return FilmstripLayout(cardWidth: 160, cardHeight: 100, filmstripHeight: 148)
        case "APP_APPLE_TV":
            // Apple TV: 16:9 landscape
            return FilmstripLayout(cardWidth: 160, cardHeight: 90, filmstripHeight: 138)
        default:
            // iPhone / iPad: 3:4 portrait
            return FilmstripLayout(cardWidth: 120, cardHeight: 160, filmstripHeight: 208)
        }
    }
}

// MARK: - ScreenshotFilmstrip

struct ScreenshotFilmstrip: View {
    let screenshots: [AppScreenshot]
    let pendingScreenshots: [PendingScreenshot]
    let displayType: String
    let onRemovePending: (PendingScreenshot) -> Void

    private var layout: FilmstripLayout {
        FilmstripLayout.make(for: displayType)
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(screenshots) { screenshot in
                    FilmstripRemoteCard(screenshot: screenshot, layout: layout)
                }

                ForEach(pendingScreenshots) { screenshot in
                    FilmstripPendingCard(screenshot: screenshot, layout: layout, onRemove: { onRemovePending(screenshot) })
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
        }
        .frame(height: layout.filmstripHeight)
    }
}

// MARK: - FilmstripRemoteCard

private struct FilmstripRemoteCard: View {
    let screenshot: AppScreenshot
    let layout: FilmstripLayout
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            thumbnail
                .frame(width: layout.cardWidth, height: layout.cardHeight)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.secondary.opacity(0.2))
                )

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
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.accentColor.opacity(isHovering ? 0.28 : 0), lineWidth: 1)
                .animation(.easeInOut(duration: 0.12), value: isHovering)
        }
        .onHover { hovering in
            isHovering = hovering
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let previewURL = screenshot.previewURL {
            CachedScreenshotThumbnail(url: previewURL, screenshotID: screenshot.id, contentMode: .fill) {
                ProgressView().controlSize(.small)
            } failure: {
                placeholder
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

// MARK: - FilmstripPendingCard

private struct FilmstripPendingCard: View {
    let screenshot: PendingScreenshot
    let layout: FilmstripLayout
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.secondary.opacity(0.08))
                    .frame(width: layout.cardWidth, height: layout.cardHeight)
                    .overlay {
                        Image(systemName: "photo")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }

                AppIconButton(systemImage: "xmark", tint: .secondary, action: onRemove)
                    .padding(4)
            }

            Text(pendingStatusLabel)
                .font(.caption2)
                .foregroundStyle(pendingStatusColor)
                .lineLimit(2)
                .frame(width: layout.cardWidth, alignment: .leading)
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
