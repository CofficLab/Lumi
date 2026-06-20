import Foundation

/// Supported video output formats.
enum VideoFormat: String, CaseIterable, Identifiable {
    case mp4
    case mov
    case mkv
    case avi
    case webm
    case gif

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .mp4: return "MP4"
        case .mov: return "MOV"
        case .mkv: return "MKV"
        case .avi: return "AVI"
        case .webm: return "WebM"
        case .gif: return "GIF"
        }
    }

    /// FFmpeg codec for this format.
    var ffmpegCodec: String {
        switch self {
        case .mp4: return "libx264"
        case .mov: return "libx264"
        case .mkv: return "libx264"
        case .avi: return "mpeg4"
        case .webm: return "libvpx-vp9"
        case .gif: return "gif"
        }
    }

    /// FFmpeg output format flag (if different from extension).
    var ffmpegFormat: String? {
        switch self {
        case .gif: return "gif"
        default: return nil
        }
    }
}
