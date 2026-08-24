import LumiUI
import SwiftUI

struct PendingScreenshotRow: View {
    let screenshot: PendingScreenshot
    let onRemove: () -> Void

    var body: some View {
        AppListRow {
            HStack(spacing: 12) {
                Image(systemName: "photo")
                    .font(.title3)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 3) {
                    Text(screenshot.fileName)
                        .font(.body.weight(.medium))
                        .lineLimit(1)
                    Text("\(screenshot.width) x \(screenshot.height) · \(screenshot.displayType)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                status

                AppIconButton(systemImage: "trash", tint: .red, action: onRemove)
            }
        }
        .appStoreConnectAddToChatMenu(
            entityType: "pendingScreenshot",
            entityID: screenshot.id.uuidString,
            title: screenshot.fileName,
            sourceView: "PendingScreenshotRow",
            fields: [
                "displayType": screenshot.displayType,
                "height": String(screenshot.height),
                "status": statusLabel,
                "width": String(screenshot.width)
            ]
        )
    }

    @ViewBuilder
    private var status: some View {
        switch screenshot.status {
        case .ready:
            Label(AppStoreConnectLocalization.string("Ready"), systemImage: "checkmark.circle")
                .foregroundStyle(.green)
        case .invalid(let message):
            Label(message, systemImage: "xmark.octagon")
                .foregroundStyle(.red)
        case .uploading:
            Label(AppStoreConnectLocalization.string("Uploading"), systemImage: "arrow.up.circle")
                .foregroundStyle(.secondary)
        case .uploaded:
            Label(AppStoreConnectLocalization.string("Uploaded"), systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.red)
        }
    }

    private var statusLabel: String {
        switch screenshot.status {
        case .ready:
            return "ready"
        case .invalid(let message):
            return "invalid: \(message)"
        case .uploading:
            return "uploading"
        case .uploaded:
            return "uploaded"
        case .failed(let message):
            return "failed: \(message)"
        }
    }
}
