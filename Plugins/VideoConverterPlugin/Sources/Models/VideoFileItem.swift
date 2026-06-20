import Foundation

/// Represents a selected video file for conversion.
struct VideoFileItem: Identifiable {
    let id = UUID()
    let url: URL
    let fileSize: UInt64

    var lastPathComponent: String {
        url.lastPathComponent
    }
}
