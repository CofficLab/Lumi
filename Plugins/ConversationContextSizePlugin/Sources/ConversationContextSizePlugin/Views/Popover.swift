import SwiftUI

struct Popover: View {
    let used: Int?
    let max: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(LumiPluginLocalization.string("Context Window", bundle: .module))
                .font(.system(size: 12, weight: .semibold))

            VStack(alignment: .leading, spacing: 6) {
                explanationRow(
                    icon: "brain",
                    text: LumiPluginLocalization.string("Maximum tokens the model can process in a single request.", bundle: .module)
                )
                explanationRow(
                    icon: "arrow.left.arrow.right",
                    text: LumiPluginLocalization.string("Includes both input (messages) and output (response).", bundle: .module)
                )
                explanationRow(
                    icon: "chart.bar",
                    text: LumiPluginLocalization.string("Larger context allows more conversation history to be sent.", bundle: .module)
                )
                explanationRow(
                    icon: "exclamationmark.triangle",
                    text: LumiPluginLocalization.string("When nearing the limit, older messages may be truncated.", bundle: .module)
                )
            }

            Divider()

            // Used tokens row (if available)
            if let used, used > 0 {
                HStack {
                    Text(LumiPluginLocalization.string("Last request:", bundle: .module))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text(used.formattedContextSizeDetail)
                        .font(.system(size: 11, weight: .semibold))
                        .monospacedDigit()
                }
            }

            // Max tokens row
            HStack {
                Text(LumiPluginLocalization.string("Model limit:", bundle: .module))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text(max.formattedContextSizeDetail)
                    .font(.system(size: 11, weight: .semibold))
                    .monospacedDigit()
            }
        }
        .padding(10)
        .frame(width: 260)
    }

    private func explanationRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 16)
            Text(text)
                .font(.system(size: 11))
                .foregroundColor(.primary)
        }
    }

}
