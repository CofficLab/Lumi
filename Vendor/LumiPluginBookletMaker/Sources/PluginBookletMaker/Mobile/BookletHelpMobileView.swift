#if os(iOS)
import SwiftUI

/// Help and privacy information arranged like the prototype's short guide.
struct BookletHelpMobileView: View {
    var onOpenGuide: ((BookletGuideKind) -> Void)?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                appCard

                section(BookletLocalization.string("Make a Booklet")) {
                    stepRow(1, BookletLocalization.string("Open PDF"),
                            BookletLocalization.string("Choose a PDF from Files or start with the built-in sample."))
                    Divider()
                    stepRow(2, BookletLocalization.string("Choose paper"),
                            BookletLocalization.string("A4, A5, or Letter. Pages are rearranged for folding and binding."))
                    Divider()
                    stepRow(3, BookletLocalization.string("Check the print sides"),
                            BookletLocalization.string("Print both sides, flip on the long edge, and fold along the center."))
                    Divider()
                    stepRow(4, BookletLocalization.string("Export and share"),
                            BookletLocalization.string("Share the finished PDF or save it to Files."))
                    if let onOpenGuide {
                        Divider()
                        guideButton(BookletLocalization.string("View the booklet guide"), kind: .booklet, action: onOpenGuide)
                    }
                }

                section(BookletLocalization.string("Split a PDF")) {
                    Text(BookletLocalization.string(
                        "Open a PDF and tap the scissors between pages to mark where each file should begin. Review the page ranges, then export."
                    ))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    if let onOpenGuide {
                        guideButton(BookletLocalization.string("View the split guide"), kind: .split, action: onOpenGuide)
                            .padding(.top, 8)
                    }
                }

                HStack(alignment: .top, spacing: 11) {
                    Image(systemName: "lock.shield.fill")
                        .foregroundStyle(BookletMobileStyle.privacyAccent)
                    Text(BookletLocalization.string(
                        "All documents are processed locally on your device. File contents are not uploaded or stored on a server."
                    ))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                .padding(14)
                .background(BookletMobileStyle.card, in: RoundedRectangle(cornerRadius: 14))

                section(BookletLocalization.string("About")) {
                    LabeledContent(BookletLocalization.string("App"), value: BookletLocalization.string("Booklet Maker"))
                    Divider()
                    LabeledContent(BookletLocalization.string("Version"), value: versionString)
                }
            }
            .padding(16)
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
        }
        .background(BookletMobileStyle.canvas)
        .navigationTitle(BookletLocalization.string("Help"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var appCard: some View {
        HStack(spacing: 13) {
            Image(systemName: "book.closed.fill")
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(BookletMobileStyle.actionFill, in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 3) {
                Text(BookletLocalization.string("Booklet Maker"))
                    .font(.headline)
                Text(BookletLocalization.string("Version %@ · processed on this device", versionString))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(15)
        .background(BookletMobileStyle.card, in: RoundedRectangle(cornerRadius: 14))
    }

    private func section<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
            VStack(alignment: .leading, spacing: 11, content: content)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(BookletMobileStyle.card, in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private func stepRow(_ number: Int, _ title: String, _ description: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.caption.weight(.bold))
                .foregroundStyle(BookletMobileStyle.accent)
                .frame(width: 23, height: 23)
                .background(BookletMobileStyle.softAccent, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.medium))
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func guideButton(
        _ title: String,
        kind: BookletGuideKind,
        action: @escaping (BookletGuideKind) -> Void
    ) -> some View {
        Button { action(kind) } label: {
            Label(title, systemImage: "play.rectangle")
                .font(.footnote.weight(.medium))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .foregroundStyle(BookletMobileStyle.accent)
        .accessibilityIdentifier("help.guide.\(kind.rawValue)")
    }

    private var versionString: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(short) (\(build))"
    }
}
#endif
