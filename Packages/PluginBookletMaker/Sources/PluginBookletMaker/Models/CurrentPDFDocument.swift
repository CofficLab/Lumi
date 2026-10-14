import Foundation

/// The single source document used by every Booklet Maker stage.
///
/// The built-in demonstration and a user-selected PDF intentionally share
/// this model so preview, imposition, binding simulation and export cannot
/// drift onto separate data paths.
struct CurrentPDFDocument: Identifiable, Equatable {
    enum Source: Equatable {
        case demo
        case user
    }

    let id: UUID
    let source: Source
    let url: URL
    let info: PDFInspector.PDFInfo

    init(id: UUID = UUID(),
         source: Source,
         url: URL,
         info: PDFInspector.PDFInfo) {
        self.id = id
        self.source = source
        self.url = url
        self.info = info
    }

    var isDemo: Bool { source == .demo }
    var pageCount: Int { info.pageCount }

    var pageAspectRatio: CGFloat {
        let size = info.firstPageSize
        guard size.width > 0, size.height > 0 else { return 1 / 1.414 }
        return size.width / size.height
    }

    var baseFileName: String {
        url.deletingPathExtension().lastPathComponent
    }
}
