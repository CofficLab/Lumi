import Combine
import Foundation

// MARK: - Mobile Workspace State

/// The mobile workspace's UI state machine.
///
/// Business values (the current document, imposition settings, split plan
/// and export results) remain in `BookletMakerViewModel`. This type owns
/// where the user is — welcome / importing / ready / generating /
/// cancelling / result / failed — the selected tool, and the single
/// presented sheet, so that several booleans can never be true at once.
@MainActor
final class MobileWorkspaceState: ObservableObject {

    // MARK: - Types

    enum Tool: String, CaseIterable, Identifiable, Sendable {
        case booklet
        case split

        var id: String { rawValue }
    }

    enum Phase: Equatable, Sendable {
        case welcome
        case importing
        case ready
        case generating
        case cancelling
        case resultReady
        case failed
    }

    /// The single sheet / system presentation currently on screen.
    /// Presenting a new item replaces the previous one.
    enum Presentation: Equatable, Identifiable {
        case bookletOptions
        case splitBatchInput
        case splitRename(PDFSplitSegment)
        case help
        case shareBooklet(URL)
        case shareSplit([URL])
        case saveBooklet(URL)
        case saveSplit([URL])

        var id: String {
            switch self {
            case .bookletOptions: "bookletOptions"
            case .splitBatchInput: "splitBatchInput"
            case .splitRename(let segment): "splitRename-\(segment.rangeKey)"
            case .help: "help"
            case .shareBooklet(let url): "shareBooklet-\(url.path)"
            case .shareSplit(let urls): "shareSplit-\(urls.map(\.path).joined(separator: "|"))"
            case .saveBooklet(let url): "saveBooklet-\(url.path)"
            case .saveSplit(let urls): "saveSplit-\(urls.map(\.path).joined(separator: "|"))"
            }
        }
    }

    // MARK: - Published state

    @Published private(set) var phase: Phase = .welcome
    @Published private(set) var selectedTool: Tool = .booklet
    @Published private(set) var presentation: Presentation?

    // MARK: - Document lifecycle

    func beginImport() {
        phase = .importing
        presentation = nil
    }

    func documentReady() {
        phase = .ready
    }

    func documentFailed() {
        phase = .failed
    }

    /// Dismiss an error and return to the previous working state.
    func dismissFailure() {
        phase = .ready
    }

    /// Close the current document and return to the welcome screen.
    func closeDocument() {
        phase = .welcome
        presentation = nil
    }

    // MARK: - Tool routing

    /// Switch the tool. Only allowed while the workspace is idle enough to
    /// start editing; never while generating or cancelling.
    func selectTool(_ tool: Tool) {
        guard phase == .ready || phase == .resultReady else { return }
        selectedTool = tool
        presentation = nil
    }

    // MARK: - Generation lifecycle

    func beginGenerating() {
        phase = .generating
        presentation = nil
    }

    func beginCancelling() {
        phase = .cancelling
    }

    func generationFinished() {
        phase = .resultReady
        presentation = nil
    }

    func generationCancelled() {
        phase = .ready
    }

    func generationFailed() {
        phase = .failed
    }

    // MARK: - Presentations

    /// Present a sheet / system controller. Passing `nil` dismisses.
    func present(_ item: Presentation?) {
        presentation = item
    }
}
