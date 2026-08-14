import LumiUI
import SwiftUI

/// 白噪音播放主视图。
struct WhiteNoiseView: View {
    @StateObject private var viewModel = WhiteNoiseViewModel()

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 16) {
                    if let error = viewModel.errorMessage {
                        ErrorBanner(message: error) { viewModel.dismissError() }
                            .transition(.opacity)
                    }

                    masterCard
                    tracksSection
                    sleepTimerCard
                }
                .padding()
                .frame(maxWidth: .infinity)
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
        }
        .frame(minWidth: 360, idealWidth: 420, minHeight: 480, idealHeight: 600)
        .animation(.easeInOut(duration: 0.2), value: viewModel.errorMessage)
    }

    // MARK: - Master

    private var masterCard: some View {
        AppCard(cornerRadius: 16, padding: EdgeInsets(top: 18, leading: 18, bottom: 18, trailing: 18)) {
            VStack(spacing: 18) {
                HStack(spacing: 14) {
                    Image(systemName: viewModel.isPlaying ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(.tint)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("White Noise")
                            .font(.system(size: 18, weight: .semibold))
                        Text(viewModel.isPlaying ? "Playing" : "Paused")
                            .font(.caption)
                            .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                    }

                    Spacer()
                }

                AppButton(
                    viewModel.isPlaying ? "Stop" : "Play",
                    systemImage: viewModel.isPlaying ? "stop.fill" : "play.fill",
                    style: .primary,
                    size: .medium,
                    fillsWidth: true
                ) {
                    viewModel.togglePlay()
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "speaker.wave.1.fill")
                            .font(.caption)
                            .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                        Text("Master Volume")
                            .font(.caption)
                            .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                        Spacer()
                        Text("\(Int(viewModel.masterVolume * 100))%")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                    }
                    Slider(value: $viewModel.masterVolume, in: 0...1) { editing in
                        if !editing { viewModel.setMaster(viewModel.masterVolume) }
                    }
                    .disabled(!viewModel.isPlaying)
                }
            }
        }
    }

    // MARK: - Tracks

    private var tracksSection: some View {
        VStack(spacing: 12) {
            ForEach(NoiseTrack.allCases) { track in
                NoiseTrackRow(viewModel: viewModel, track: track)
            }
        }
    }

    // MARK: - Sleep Timer

    private var sleepTimerCard: some View {
        AppCard(cornerRadius: 16, padding: EdgeInsets(top: 18, leading: 18, bottom: 18, trailing: 18)) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.tint)
                    Text("Sleep Timer")
                        .font(.system(size: 15, weight: .medium))
                    Spacer()
                    if let remaining = viewModel.remainingSeconds {
                        Text(formatCountdown(remaining))
                            .font(.caption.monospacedDigit())
                            .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                    }
                }

                Picker("Sleep Timer", selection: $viewModel.sleepDuration) {
                    ForEach(WhiteNoiseViewModel.SleepDuration.allCases) { duration in
                        Text(duration.title).tag(duration)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(!viewModel.isPlaying)
            }
        }
    }

    private func formatCountdown(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

/// 单个噪声轨：开关 + 音量。
private struct NoiseTrackRow: View {
    @ObservedObject var viewModel: WhiteNoiseViewModel
    let track: NoiseTrack

    private var isOn: Binding<Bool> {
        Binding(
            get: {
                switch track {
                case .white: return viewModel.whiteEnabled
                case .pink: return viewModel.pinkEnabled
                case .brown: return viewModel.brownEnabled
                }
            },
            set: { viewModel.setEnabled($0, for: track) }
        )
    }

    private var volume: Binding<Float> {
        Binding(
            get: {
                switch track {
                case .white: return viewModel.whiteVolume
                case .pink: return viewModel.pinkVolume
                case .brown: return viewModel.brownVolume
                }
            },
            set: { viewModel.setVolume($0, for: track) }
        )
    }

    var body: some View {
        AppCard(cornerRadius: 14, padding: EdgeInsets(top: 14, leading: 14, bottom: 14, trailing: 14)) {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: track.systemImage)
                        .font(.system(size: 18))
                        .foregroundColor(track.tintColor)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.title)
                            .font(.system(size: 14, weight: .medium))
                        Text(track.subtitle)
                            .font(.caption2)
                            .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                    }

                    Spacer()

                    Toggle("", isOn: isOn)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .labelsHidden()
                }

                HStack(spacing: 10) {
                    Slider(value: volume, in: 0...1)
                        .disabled(!isOn.wrappedValue)
                    Text("\(Int(volume.wrappedValue * 100))%")
                        .font(.caption2.monospacedDigit())
                        .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                        .frame(width: 38, alignment: .trailing)
                }
            }
        }
    }
}

/// 临时错误提示条。
private struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(Color(hex: "FF453A"))
            Text(message)
                .font(.caption)
                .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
            Spacer()
            AppIconButton(systemImage: "xmark") { onDismiss() }
        }
        .padding(12)
        .background(Color(hex: "FF453A").opacity(0.08))
        .cornerRadius(10)
    }
}
