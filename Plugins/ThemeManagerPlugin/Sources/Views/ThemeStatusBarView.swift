#if canImport(AppKit)
import SwiftUI
import LumiKernel
import LumiUI

struct ThemeStatusBarView: View {
    private let kernel: LumiKernel
    private var themeService: (any UIThemeProviding)? {
        kernel.theme
    }

    @State private var selectedContribution: LumiUIThemeContribution?

    init(kernel: LumiKernel) {
        self.kernel = kernel
        self._selectedContribution = State(initialValue: kernel.theme?.selectedContribution)
    }

    var body: some View {
        StatusBarHoverContainer(
            detailView: ThemePickerDetailView(kernel: kernel),
            popoverWidth: 320,
            id: "lumi-theme-picker"
        ) {
            HStack(spacing: 4) {
                Image(systemName: "paintbrush")
                    .font(.appMicroEmphasized)
                if let contribution = selectedContribution {
                    Text(contribution.displayName)
                        .font(.appMicro)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .onLumiThemeDidChange {
            selectedContribution = themeService?.selectedContribution
        }
    }
}
#endif
