import SwiftUI

/// Conversion settings and progress view.
struct ConversionSettingsView: View {
    let file: VideoFileItem
    @Binding var outputFormat: VideoFormat
    let isConverting: Bool
    let progress: Double
    let onConvert: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Output Format")
                .font(.subheadline.bold())

            Picker("Format", selection: $outputFormat) {
                ForEach(VideoFormat.allCases) { format in
                    Text(format.displayName).tag(format)
                }
            }
            .pickerStyle(.segmented)

            if isConverting {
                VStack(spacing: 8) {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)

                    HStack {
                        Text("\(Int(progress * 100))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Cancel", role: .destructive) {
                            onCancel()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            } else {
                Button(action: onConvert) {
                    Label("Convert", systemImage: "arrow.right.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
    }
}

#Preview {
    ConversionSettingsView(
        file: VideoFileItem(url: URL(fileURLWithPath: "/tmp/test.mp4"), fileSize: 1024 * 1024 * 50),
        outputFormat: .constant(.mp4),
        isConverting: false,
        progress: 0,
        onConvert: {},
        onCancel: {}
    )
    .padding()
    .frame(width: 400)
}
