import Foundation
import SwiftUI

/// A seekable progress slider for audio and video playback.
///
/// The binding is normalized at both read and write boundaries so invalid
/// durations and out-of-range player values never reach `Slider`.
public struct AppPlaybackProgressBar: View {
    @Binding private var currentTime: TimeInterval
    @LumiTheme private var theme

    private let duration: TimeInterval
    private let onSeek: (TimeInterval) -> Void

    public init(
        currentTime: Binding<TimeInterval>,
        duration: TimeInterval,
        onSeek: @escaping (TimeInterval) -> Void
    ) {
        self._currentTime = currentTime
        self.duration = duration
        self.onSeek = onSeek
    }

    public var body: some View {
        Slider(
            value: Binding(
                get: {
                    AppPlaybackProgress.normalizedTime(currentTime, duration: duration)
                },
                set: { value in
                    let normalized = AppPlaybackProgress.normalizedTime(value, duration: duration)
                    currentTime = normalized
                    onSeek(normalized)
                }
            ),
            in: 0...AppPlaybackProgress.sliderUpperBound(forDuration: duration)
        )
        .tint(theme.primary)
        .accessibilityLabel(Text("Playback progress"))
        .accessibilityValue(
            Text(AppPlaybackProgress.formattedTime(
                AppPlaybackProgress.normalizedTime(currentTime, duration: duration)
            ))
        )
    }
}

/// Playback time and seek calculations shared by media controls.
public enum AppPlaybackProgress {
    public static func normalizedDuration(_ duration: TimeInterval) -> TimeInterval {
        guard duration.isFinite, duration > 0 else { return 0 }
        return duration
    }

    public static func normalizedTime(_ time: TimeInterval, duration: TimeInterval) -> TimeInterval {
        guard time.isFinite else { return 0 }
        let duration = normalizedDuration(duration)
        guard duration > 0 else { return 0 }
        return min(max(time, 0), duration)
    }

    public static func normalizedProgress(currentTime: TimeInterval, duration: TimeInterval) -> Double {
        let duration = normalizedDuration(duration)
        guard duration > 0 else { return 0 }
        return normalizedTime(currentTime, duration: duration) / duration
    }

    public static func seekTime(locationX: CGFloat, trackWidth: CGFloat, duration: TimeInterval) -> TimeInterval {
        let duration = normalizedDuration(duration)
        guard duration > 0, locationX.isFinite, trackWidth.isFinite, trackWidth > 0 else { return 0 }
        let ratio = min(max(Double(locationX / trackWidth), 0), 1)
        return ratio * duration
    }

    public static func sliderUpperBound(forDuration duration: TimeInterval) -> TimeInterval {
        max(normalizedDuration(duration), 1)
    }

    public static func formattedTime(_ time: TimeInterval) -> String {
        let safeTime = time.isFinite ? max(time, 0) : 0
        let totalSeconds = Int(min(safeTime, TimeInterval(Int.max / 2)))
        return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
    }
}
