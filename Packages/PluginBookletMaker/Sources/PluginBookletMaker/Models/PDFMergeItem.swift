import Foundation

/// One PDF in the merge queue.
struct PDFMergeItem: Identifiable, Equatable, Sendable {
    let id: UUID
    let url: URL
    let pageCount: Int

    init(id: UUID = UUID(), url: URL, pageCount: Int) {
        self.id = id
        self.url = url
        self.pageCount = pageCount
    }
}
