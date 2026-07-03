import LumiUI
import SwiftUI

struct ThinkingBlockView: View {
    @LumiTheme private var theme
    let text: String
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "brain")
                        .font(.caption)
                    Text("思考过程")
                        .font(.appMicro)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                }
                .foregroundColor(theme.textSecondary)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Text(text)
                    .font(.appMicro)
                    .foregroundColor(theme.textSecondary)
                    .textSelection(.enabled)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .appSurface(style: .panel, cornerRadius: 6)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}
