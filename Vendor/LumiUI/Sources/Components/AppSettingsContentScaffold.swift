import SwiftUI

/// Lightweight settings detail scaffold without a page title (sidebar shows the active tab).
///
/// - macOS：滚动区 + 面板底色，内容最大宽度受限，呈现桌面侧栏详情区。
/// - iOS：分组列表底色（`systemGroupedBackground`），内容左右各留 16pt，
///   与 iOS 分组卡片的边距对齐。
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
        #if os(iOS) || os(visionOS)
        iosBody
        #else
        macBody
        #endif
    }

    // MARK: - macOS

    private var macBody: some View {
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
            // Full-height split views (sidebar + detail) own their scrolling and
            // should reach the bottom edge of the settings content area. The
            // regular scrolling variant keeps the symmetric page padding.
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, scrollsContent ? 24 : 0)
            .frame(maxWidth: maxContentWidth, alignment: .leading)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - iOS

    private var iosBody: some View {
        Group {
            if scrollsContent {
                ScrollView {
                    iosContent
                }
            } else {
                iosContent
            }
        }
        .background(Color.lumiGroupedBackground)
    }

    private var iosContent: some View {
        content
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, scrollsContent ? 24 : 0)
            .frame(maxWidth: maxContentWidth, alignment: .leading)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
