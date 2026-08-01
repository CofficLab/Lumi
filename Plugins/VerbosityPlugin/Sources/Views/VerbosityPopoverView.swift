import LumiKernel
import SwiftUI

struct VerbosityPopover: View {
    let selectedLevel: LumiResponseVerbosity
    let onSelect: (LumiResponseVerbosity) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Verbosity Level")
                .font(.system(size: 12, weight: .semibold))

            ForEach(LumiResponseVerbosity.allCases) { level in
                Button {
                    onSelect(level)
                } label: {
                    VerbosityRow(level: level, isSelected: level == selectedLevel)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .frame(width: 260)
    }
}
