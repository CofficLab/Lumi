import CoreGraphics
import Foundation

// MARK: - Paper Size

/// Common output paper sizes in millimetres.
///
/// All conversion to PDF point space uses the standard
/// `1 mm = 72 / 25.4 pt` factor.
enum PaperSize: String, CaseIterable, Identifiable, Codable, Sendable {
    case a4
    case a5
    case letter

    var id: String { rawValue }

    /// Display name used in the settings UI.
    var displayName: String {
        switch self {
        case .a4:     return "A4"
        case .a5:     return "A5"
        case .letter: return "Letter"
        }
    }

    /// Width in millimetres.
    var widthMM: Double {
        switch self {
        case .a4:     return 210
        case .a5:     return 148
        case .letter: return 215.9
        }
    }

    /// Height in millimetres.
    var heightMM: Double {
        switch self {
        case .a4:     return 297
        case .a5:     return 210
        case .letter: return 279.4
        }
    }

    /// Size in PDF points (1 pt = 1/72 inch).
    var sizeInPoints: CGSize {
        CGSize(width: mmToPt(widthMM), height: mmToPt(heightMM))
    }

    /// Size used by the booklet renderer: the output sheet is landscape.
    var landscapeSizeInPoints: CGSize {
        CGSize(width: mmToPt(heightMM), height: mmToPt(widthMM))
    }

    // MARK: - Unit conversion

    /// Convert millimetres to PDF points.
    static func mmToPt(_ mm: Double) -> Double {
        mm * 72.0 / 25.4
    }

    /// Convert PDF points to millimetres.
    static func ptToMM(_ pt: Double) -> Double {
        pt * 25.4 / 72.0
    }

    /// Shorthand for the static converter.
    var mmToPt: (Double) -> Double { PaperSize.mmToPt }
}
