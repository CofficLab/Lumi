import SwiftUI

/// Displays the conversion log output.
struct ConversionLogView: View {
    let log: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(VideoConverterLocalization.string("Log"))
                    .font(.subheadline.bold())
                Spacer()
            }

            ScrollView {
                Text(log)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(maxHeight: 120)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.05))
            )
        }
    }
}

#Preview {
    ConversionLogView(log: "Input: test.mov\nOutput: test.mp4\nConverting...\nDone!")
        .padding()
        .frame(width: 400)
}
