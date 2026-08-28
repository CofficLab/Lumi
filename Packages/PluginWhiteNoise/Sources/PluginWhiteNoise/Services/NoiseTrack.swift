import SwiftUI

/// 可播放的噪声类型。
///
/// 三种噪声的频谱能量分布不同，听感各异：
/// - white：全频段等能量，听起来像「沙沙」声，最尖锐。
/// - pink：每倍频能量恒定，比白噪声柔和，常用于专注/掩蔽。
/// - brown：低频能量为主，类似海浪/远雷，最低沉。
enum NoiseTrack: String, CaseIterable, Identifiable {
    case white
    case pink
    case brown

    var id: String { rawValue }

    var title: String {
        switch self {
        case .white: return "White Noise"
        case .pink: return "Pink Noise"
        case .brown: return "Brown Noise"
        }
    }

    var subtitle: String {
        switch self {
        case .white: return "Equal energy across all frequencies"
        case .pink: return "Equal energy per octave, softer"
        case .brown: return "Deeper, low-frequency rumble"
        }
    }

    /// 用于区分三轨的 SF Symbol。
    var systemImage: String {
        switch self {
        case .white: return "circle.hexagongrid.fill"
        case .pink: return "circle.hexagonpath.fill"
        case .brown: return "waveform"
        }
    }

    /// 三轨各用一种强调色，便于在 UI 上区分。
    var tintColor: Color {
        switch self {
        case .white: return Color(red: 0.78, green: 0.84, blue: 0.98)
        case .pink: return Color(red: 0.99, green: 0.66, blue: 0.78)
        case .brown: return Color(red: 0.80, green: 0.65, blue: 0.45)
        }
    }
}
