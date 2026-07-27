import SwiftUI
import LumiUI
import LumiKernel

struct ThemeStatusBarView: View {
    private let kernel: LumiKernel

    init(kernel: LumiKernel) {
        self.kernel = kernel
    }

    private var themeService: (any UIThemeProviding)? {
        kernel.theme
    }

    private var registry: LumiUIThemeRegistry? {
        themeService?.themeRegistry
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
                if let contribution = registry?.selectedContribution {
                    Text(contribution.displayName)
                        .font(.appMicro)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }
}
