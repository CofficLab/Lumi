#if os(iOS)
import SwiftUI

/// 帮助与关于：操作指引、隐私说明与应用信息。
struct BookletHelpMobileView: View {
    var body: some View {
        List {
            Section(BookletLocalization.string("Make a Booklet")) {
                Text(helpBookletText)
                    .font(.footnote)
            }

            Section(BookletLocalization.string("Split a PDF")) {
                Text(helpSplitText)
                    .font(.footnote)
            }

            Section(BookletLocalization.string("Privacy")) {
                Text(privacyText)
                    .font(.footnote)
            }

            Section(BookletLocalization.string("About")) {
                LabeledContent(
                    BookletLocalization.string("App"),
                    value: "BookletMaker"
                )
                LabeledContent(
                    BookletLocalization.string("Version"),
                    value: versionString
                )
            }
        }
        .navigationTitle(BookletLocalization.string("Help"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var helpBookletText: String {
        BookletLocalization.string(
            "Open a PDF, choose Booklet, and the pages are reordered so "
            + "two printed sides become one folded sheet. Pick your paper, "
            + "review the print sides, then export and share the result."
        )
    }

    private var helpSplitText: String {
        BookletLocalization.string(
            "Open a PDF, choose Split PDF, and tap between pages to mark "
            + "where the file should break. Name each part, then export "
            + "and share the resulting PDFs."
        )
    }

    private var privacyText: String {
        BookletLocalization.string(
            "BookletMaker processes every document locally on your device. "
            + "No file content is uploaded or stored on any server."
        )
    }

    private var versionString: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(short) (\(build))"
    }
}
#endif
