import AppKit
import LumiUI
import SwiftUI

/// Shown instead of `HTTPExchangePayloadView` when a body exceeds the
/// `largePayloadByteThreshold`. Displays size + MIME type metadata and
/// offers a text export action without rendering
/// the raw bytes.
struct HTTPExchangeLargePayloadView: View {
    @LumiTheme private var theme

    /// Which body this view represents (request or response).
    enum BodyKind: String, Sendable {
        case request
        case response
    }

    let bodyKind: BodyKind
    let bodyData: Data?
    let mimeType: String?
    let recordID: UUID

    @State private var exportError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Metadata row
            HStack(spacing: 16) {
                metadataPill(
                    pluginLocalization.string("Size"),
                    ByteCountFormatter.string(fromByteCount: Int64(bodyData?.count ?? 0), countStyle: .binary)
                )
                if let mimeType, !mimeType.isEmpty {
                    metadataPill(
                        pluginLocalization.string("Type"),
                        mimeType
                    )
                }
            }

            // Action buttons
            HStack(spacing: 8) {
                AppButton(
                    pluginLocalization.string("Download Body"),
                    systemImage: "arrow.down.doc",
                    size: .small
                ) {
                    exportBodyAsText()
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
        .padding(12)
        .background(theme.textSecondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .alert(
            pluginLocalization.string("Export failed"),
            isPresented: Binding(
                get: { exportError != nil },
                set: { if !$0 { exportError = nil } }
            )
        ) {
            Button(pluginLocalization.string("OK"), role: .cancel) {}
        } message: {
            Text(exportError ?? "")
        }
    }

    @ViewBuilder
    private func metadataPill(_ label: String, _ value: String) -> some View {
        HStack(spacing: 6) {
            Text(label + ":")
                .font(.appCaption)
                .foregroundStyle(theme.textSecondary)
            Text(value)
                .font(.appCaptionEmphasized)
                .foregroundStyle(theme.textPrimary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(theme.textSecondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
    }

    private func exportBodyAsText() {
        guard let bodyData, !bodyData.isEmpty else {
            exportError = pluginLocalization.string("No body data to save.")
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.canCreateDirectories = true
        let shortID = String(recordID.uuidString.prefix(8))
        panel.nameFieldStringValue = "body-" + bodyKind.rawValue + "-" + shortID + ".txt"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try HTTPExchangeExportFormatter.text(bodyData)
                .write(to: url, atomically: true, encoding: .utf8)
        } catch {
            exportError = error.localizedDescription
        }
    }
}
