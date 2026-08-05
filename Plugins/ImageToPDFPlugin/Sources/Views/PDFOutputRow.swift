import SwiftUI

/// Single row in the output PDF list with status, progress, and actions.
struct PDFOutputRow: View {
    let item: PDFOutputItem
    let onReveal: () -> Void
    let onOpen: () -> Void
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                thumbnail
                    .frame(width: 40, height: 40)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.source.suggestedPDFName)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    statusLine
                }

                Spacer()

                actions
            }

            if item.progress > 0 && item.progress < 1 {
                ProgressView(value: item.progress)
                    .progressViewStyle(.linear)
            }
        }
        .padding(.vertical, 6)
    }

    private var statusLine: some View {
        HStack(spacing: 6) {
            statusBadge
            if case .failed(let message) = item.status {
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                    .lineLimit(1)
            }
        }
    }

    private var statusBadgeColor: Color {
        switch item.status {
        case .pending:    return .secondary
        case .processing: return .blue
        case .done:       return .green
        case .failed:     return .red
        }
    }

    private var statusBadge: some View {
        Text(item.displayStatus)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(statusBadgeColor)
    }

    private var actions: some View {
        HStack(spacing: 6) {
            Button(action: onOpen) {
                Image(systemName: "eye")
            }
            .buttonStyle(.plain)
            .help(ImageToPDFLocalization.string("Open"))
            .disabled(item.status.outputURL == nil)

            Button(action: onReveal) {
                Image(systemName: "folder")
            }
            .buttonStyle(.plain)
            .help(ImageToPDFLocalization.string("Reveal in Finder"))
            .disabled(item.status.outputURL == nil)

            Button(action: onRemove) {
                Image(systemName: "trash")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help(ImageToPDFLocalization.string("Remove"))
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let outputURL = item.status.outputURL,
           let nsImage = bestThumbnail(for: outputURL) {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFill()
        } else if let nsImage = NSImage(contentsOf: item.source.url) {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFill()
        } else {
            Image(systemName: "doc.richtext")
                .foregroundStyle(.secondary)
        }
    }

    /// Best-effort thumbnail for the produced PDF. Falls back to the source
    /// image when PDFKit can't render it quickly.
    private func bestThumbnail(for url: URL) -> NSImage? {
        guard let pdf = PDFKit.PDFDocument(url: url),
              let page = pdf.page(at: 0) else {
            return nil
        }
        let bounds = page.bounds(for: .mediaBox)
        let image = NSImage(size: bounds.size)
        image.lockFocus()
        if let ctx = NSGraphicsContext.current?.cgContext {
            ctx.saveGState()
            ctx.setFillColor(.white)
            ctx.fill(NSRect(origin: .zero, size: bounds.size))
            page.draw(with: .mediaBox, to: ctx)
            ctx.restoreGState()
        }
        image.unlockFocus()
        return image
    }
}

import PDFKit