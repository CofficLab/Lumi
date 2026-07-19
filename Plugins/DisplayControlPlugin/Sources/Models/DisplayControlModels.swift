import CoreGraphics
import Foundation

// MARK: - Display Control Kind

enum DisplayControlKind: Hashable, Sendable {
    case brightness
    case volume
    case contrast

    var defaultValue: Double {
        switch self {
        case .brightness: 50
        case .volume: 40
        case .contrast: 75
        }
    }

    var storageKey: String {
        switch self {
        case .brightness: "brightness"
        case .volume: "volume"
        case .contrast: "contrast"
        }
    }

    var localizationKey: String {
        switch self {
        case .brightness: "Brightness"
        case .volume: "Volume"
        case .contrast: "Contrast"
        }
    }

    func label(locale: Locale = .current) -> String {
        LumiPluginLocalization.string(localizationKey, bundle: .module, locale: locale)
    }

    var icon: String {
        switch self {
        case .brightness: "sun.max"
        case .volume: "speaker.wave.2"
        case .contrast: "circle.lefthalf.filled"
        }
    }
}

// MARK: - Controlled Display

struct ControlledDisplay: Identifiable {
    let id: CGDirectDisplayID
    let storageID: String
    let name: String
    let isBuiltIn: Bool
    var supportsBrightness: Bool
    var supportsVolume: Bool
    var supportsContrast: Bool
    var brightness: Double
    var volume: Double
    var contrast: Double

    func supports(_ control: DisplayControlKind) -> Bool {
        switch control {
        case .brightness: supportsBrightness
        case .volume: supportsVolume
        case .contrast: supportsContrast
        }
    }

    func value(for control: DisplayControlKind) -> Double {
        switch control {
        case .brightness: brightness
        case .volume: volume
        case .contrast: contrast
        }
    }

    mutating func setValue(_ value: Double, for control: DisplayControlKind) {
        switch control {
        case .brightness: brightness = value
        case .volume: volume = value
        case .contrast: contrast = value
        }
    }

    mutating func setSupported(_ isSupported: Bool, for control: DisplayControlKind) {
        switch control {
        case .brightness: supportsBrightness = isSupported
        case .volume: supportsVolume = isSupported
        case .contrast: supportsContrast = isSupported
        }
    }
}

// MARK: - Control Key

struct ControlKey: Hashable {
    let displayID: CGDirectDisplayID
    let control: DisplayControlKind
}

// MARK: - Write Result

struct DisplayWriteResult {
    let key: ControlKey
    let value: Double
    let success: Bool
}
