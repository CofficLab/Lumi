import SwiftUI
import LumiUI

struct ThemeStatusBarView: View {
    private let themeService: any LumiThemeServicing
    @ObservedObject private var registry: LumiUIThemeRegistry

    init(themeService: any LumiThemeServicing) {
        self.themeService = themeService
        self.registry = themeService.themeRegistry
    }

    var body: some View {
        StatusBarHoverContainer(
            detailView: ThemePickerDetailView(themeService: themeService),
            popoverWidth: 320,
            id: "lumi-theme-picker"
        ) {
            HStack(spacing: 4) {
                Image(systemName: "paintbrush")
                    .font(.appMicroEmphasized)
                if let contribution = registry.selectedContribution {
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
