import AppKit
import Foundation
import LumiPreviewKit

enum EditorRemoteHotPreviewHostState: String {
    case idle
    case launching
    case connected
    case rendering
    case failed

    var title: String {
        switch self {
        case .idle: String(localized: "Idle", table: "EditorPreview")
        case .launching: String(localized: "Launching", table: "EditorPreview")
        case .connected: String(localized: "Connected", table: "EditorPreview")
        case .rendering: String(localized: "Rendering", table: "EditorPreview")
        case .failed: String(localized: "Failed", table: "EditorPreview")
        }
    }
}

enum EditorRemoteHotPreviewUpdatePhase: String, Equatable {
    case idle
    case waitingToRefresh
    case refreshing

    var title: String? {
        switch self {
        case .idle: nil
        case .waitingToRefresh: String(localized: "Waiting to Refresh", table: "EditorPreview")
        case .refreshing: String(localized: "Refreshing Preview", table: "EditorPreview")
        }
    }
}

struct EditorRemoteHotPreviewFrame: Equatable, Sendable {
    let frameID: UInt64
    let size: CGSize
    let scale: CGFloat
    let renderedAt: Date

    var summary: String {
        String(
            format: String(localized: "Frame %lld - %lldx%lld @%@x", table: "EditorPreview"),
            Int64(frameID),
            Int64(size.width),
            Int64(size.height),
            String(format: "%.1f", scale)
        )
    }
}

enum EditorRemoteHotPreviewCommand: Equatable {
    case start(reason: String)
    case reload(reason: String)
    case stop(reason: String)
}

enum EditorRemoteHotPreviewEvent: Equatable {
    case frameRendered(EditorRemoteHotPreviewFrame)
    case sessionStopped(reason: String)
    case failed(message: String)
}
