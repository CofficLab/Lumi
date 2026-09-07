import Foundation

// MARK: - Export Job & Result

/// A value type describing one export attempt.
///
/// A job captures an immutable snapshot of the source document and the
/// parameters (settings or split outputs) so that UI edits made while the
/// job is in flight cannot change the meaning of the task.
struct PDFExportJob: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case booklet(settings: BookletSettings)
        case split(outputs: [PDFSplitOutput])
    }

    let id: UUID
    let documentID: UUID
    let sourceURL: URL
    let kind: Kind
    let outputDirectory: URL
}

/// The explicit result of a completed export job.
///
/// Success is only ever derived from this value being returned by a
/// service — never inferred from "some path exists on disk".
struct PDFExportResult: Equatable, Sendable {
    let jobID: UUID
    let urls: [URL]

    init(jobID: UUID, urls: [URL]) {
        self.jobID = jobID
        self.urls = urls
    }
}
