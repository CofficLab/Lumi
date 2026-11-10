import CoreGraphics
import Foundation

/// Supported output paper sizes.
public enum PaperSize: String, CaseIterable, Identifiable, Codable, Sendable {
    case a4
    case a5
    case letter

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .a4: "A4"
        case .a5: "A5"
        case .letter: "Letter"
        }
    }

    public var widthMM: Double {
        switch self {
        case .a4: 210
        case .a5: 148
        case .letter: 215.9
        }
    }

    public var heightMM: Double {
        switch self {
        case .a4: 297
        case .a5: 210
        case .letter: 279.4
        }
    }

    public var sizeInPoints: CGSize {
        CGSize(width: Self.mmToPt(widthMM), height: Self.mmToPt(heightMM))
    }

    public var landscapeSizeInPoints: CGSize {
        CGSize(width: Self.mmToPt(heightMM), height: Self.mmToPt(widthMM))
    }

    public static func mmToPt(_ mm: Double) -> Double {
        mm * 72 / 25.4
    }

    public static func ptToMM(_ pt: Double) -> Double {
        pt * 25.4 / 72
    }
}
