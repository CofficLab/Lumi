import AppKit
import Foundation
import LumiPreviewKit

enum EditorPreviewRemoteConstants {
    static let pluginID = "EditorRemotePreview"
    static let localizationTable = "EditorRemotePreview"
    static let bottomTabID = "editor-bottom-remote-preview"
}

enum EditorPreviewRemoteHostState: String {
    case idle
    case launching
    case connected
    case rendering
    case failed

    var title: String {
        switch self {
        case .idle:
            String(localized: "Idle", table: EditorPreviewRemoteConstants.localizationTable)
        case .launching:
            String(localized: "Launching", table: EditorPreviewRemoteConstants.localizationTable)
        case .connected:
            String(localized: "Connected", table: EditorPreviewRemoteConstants.localizationTable)
        case .rendering:
            String(localized: "Rendering", table: EditorPreviewRemoteConstants.localizationTable)
        case .failed:
            String(localized: "Failed", table: EditorPreviewRemoteConstants.localizationTable)
        }
    }
}

enum EditorPreviewRemoteUpdatePhase: String, Equatable {
    case idle
    case waitingToRefresh
    case refreshing

    var title: String? {
        switch self {
        case .idle:
            nil
        case .waitingToRefresh:
            String(localized: "Waiting to Refresh", table: EditorPreviewRemoteConstants.localizationTable)
        case .refreshing:
            String(localized: "Refreshing Preview", table: EditorPreviewRemoteConstants.localizationTable)
        }
    }
}

struct EditorPreviewRemoteFrame: Equatable, Sendable {
    let frameID: UInt64
    let size: CGSize
    let scale: CGFloat
    let renderedAt: Date

    var summary: String {
        let width = Int(size.width)
        let height = Int(size.height)
        return "Frame \(frameID) - \(width)x\(height) @\(String(format: "%.1f", scale))x"
    }
}

enum EditorPreviewRemoteCommand: Equatable {
    case start(reason: String)
    case reload(reason: String)
    case stop(reason: String)
}

enum EditorPreviewRemoteEvent: Equatable {
    case frameRendered(EditorPreviewRemoteFrame)
    case sessionStopped(reason: String)
    case failed(message: String)
}
