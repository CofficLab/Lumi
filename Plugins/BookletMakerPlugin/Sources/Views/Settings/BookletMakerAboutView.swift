import SwiftUI

// MARK: - Booklet Maker About View

/// Short description shown in the plugin's "About" pane.
struct BookletMakerAboutView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(BookletLocalization.string("Booklet Maker"),
                  systemImage: "book.closed")
                .font(.headline)
            Text(BookletLocalization.string(
                "Convert a PDF into a 2-up imposition ready for A4 duplex printing, folding and stapling."
            ))
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    BookletMakerAboutView()
}
