import LumiKernel
import LumiKernel
import LumiUI
import SwiftUI

struct CollapsiblePlainText: View {
    @LumiTheme private var theme

    let text: String
    @State private var isCollapsed = true

    private let collapseLineLimit = 40

    var body: some View {
        let lines = text.components(separatedBy: .newlines)
        let shouldCollapse = lines.count > collapseLineLimit
        let rendered = shouldCollapse && isCollapsed
            ? lines.prefix(collapseLineLimit).joined(separator: "\n") + "\n..."
            : text

        VStack(alignment: .leading, spacing: 6) {
            Text(rendered)
                .font(.appBody)
                .foregroundColor(theme.textPrimary)
                .lineSpacing(3)
                .textSelection(.enabled)

            if shouldCollapse {
                Button(isCollapsed ? LumiPluginLocalization.string("Show more", bundle: .module) : LumiPluginLocalization.string("Show less", bundle: .module)) {
                    isCollapsed.toggle()
                }
                .buttonStyle(.plain)
                .font(.appCaption)
                .foregroundColor(theme.primary)
            }
        }
    }
}
