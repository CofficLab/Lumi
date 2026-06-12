import SwiftUI

/// Lightweight settings detail scaffold without a page title (sidebar shows the active tab).
public struct AppSettingsContentScaffold<Content: View>: View {
    let content: Content
    let scrollsContent: Bool
    let maxContentWidth: CGFloat?
    let surfaceStyle: AppSurfaceStyle

    public init(
        scrollsContent: Bool = true,
        maxContentWidth: CGFloat? = 640,
        surfaceStyle: AppSurfaceStyle = .panel,
        @ViewBuilder content: () -> Content
    ) {
        self.scrollsContent = scrollsContent
        self.maxContentWidth = maxContentWidth
        self.surfaceStyle = surfaceStyle
        self.content = content()
    }

    public var body: some View {
        Group {
            if scrollsContent {
                ScrollView {
                    scaffoldContent
                }
            } else {
                scaffoldContent
            }
        }
        .appSurface(style: surfaceStyle, cornerRadius: 0)
    }

    private var scaffoldContent: some View {
        content
            .padding(24)
            .frame(maxWidth: maxContentWidth, alignment: .leading)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
