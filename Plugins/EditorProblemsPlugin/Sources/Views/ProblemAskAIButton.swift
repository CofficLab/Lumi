import LumiKernel
import SwiftUI

struct ProblemAskAIButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "sparkle")
                .font(.caption)
                .foregroundStyle(.purple)
        }
        .buttonStyle(.borderless)
        .help(LumiPluginLocalization.string("Ask AI to fix this problem", bundle: .module))
    }
}
