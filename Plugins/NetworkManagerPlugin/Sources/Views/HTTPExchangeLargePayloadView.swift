import AppKit
import LumiUI
import SwiftUI

/// Shown instead of `HTTPExchangePayloadView` when a body exceeds the
/// `largePayloadByteThreshold`. Displays size + MIME type metadata and
/// offers "Download Body" and "Reveal in Finder" actions without rendering
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
    let dataDirectoryURL: URL

    @State private var downloadError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Metadata row
            HStack(spacing: 16) {
                metadataPill(
                    LumiPluginLocalization.string("Size", bundle: .module),
                    ByteCountFormatter.string(fromByteCount: Int64(bodyData?.count ?? 0), countStyle: .binary)
                )
                if let mimeType, !mimeType.isEmpty {
                    metadataPill(
                        LumiPluginLocalization.string("Type", bundle: .module),
                        mimeType
                    )
                }
            }

            // Action buttons
            HStack(spacing: 8) {
                AppButton(
                    LumiPluginLocalization.string("Download Body", bundle: .module),
                    systemImage: "arrow.down.doc",
                    size: .small
                ) {
                    downloadBody()
                }

                AppButton(
                    LumiPluginLocalization.string("Reveal in Finder", bundle: .module),
                    systemImage: "folder",
                    size: .small,
                    action: { NSWorkspace.shared.open(dataDirectoryURL) }
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(theme.textSecondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .alert(
            LumiPluginLocalization.string("Download failed", bundle: .module),
            isPresented: Binding(
                get: { downloadError != nil },
                set: { if !$0 { downloadError = nil } }
            )
        ) {
            Button(LumiPluginLocalization.string("OK", bundle: .module), role: .cancel) {}
        } message: {
            Text(downloadError ?? "")
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

    private func downloadBody() {
        guard let bodyData, !bodyData.isEmpty else {
            downloadError = LumiPluginLocalization.string("No body data to save.", bundle: .module)
            return
        }

        do {
            let url = try HTTPExchangeBodyFileWriter.savePanelAndWrite(
                body: bodyData,
                recordID: recordID,
                kind: HTTPExchangeBodyFileWriter.BodyKind(rawValue: bodyKind.rawValue) ?? .response,
                mimeType: mimeType
            )
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } catch {
            // "Cancelled" is silently ignored.
            if error.localizedDescription != "Cancelled" {
                downloadError = error.localizedDescription
            }
        }
    }
}
