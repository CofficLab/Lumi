import LumiUI
import SwiftUI

/// 输入框卡片的尺寸常量。
///
/// 单独成文件是为了让「卡片长什么样」只有一处定义:视图用它渲染,
/// 渲染级测试用同一组常量推算几何,两边不会各写一份数字后悄悄漂移。
enum ComposerLayout {
    /// 卡片内文字的左右内边距(点)。
    static let contentHorizontalInset: CGFloat = 12

    /// 卡片内文字的上内边距(点)。
    static let contentTopInset: CGFloat = 10

    /// 卡片内文字的下内边距(点)。
    static let contentBottomInset: CGFloat = 10

    /// 卡片与聊天区左右边缘的间距(点)。
    ///
    /// 贴着边缘的输入框读起来是「聊天区的一部分」,留出间距才有「浮起来」的观感。
    static let outerHorizontalInset: CGFloat = 14

    /// 卡片与上方内容之间的间距(点)。
    static let outerTopInset: CGFloat = 8

    /// 卡片与下方操作栏之间的间距(点)。
    static let outerBottomInset: CGFloat = 8

    /// 卡片圆角(点)。
    static let cornerRadius: CGFloat = 16

    /// 投影的模糊半径(点)。
    static let shadowRadius: CGFloat = 16

    /// 投影的垂直偏移(点):向下偏,阴影才落在卡片下缘之外。
    static let shadowOffsetY: CGFloat = 5
}

/// 输入框的「悬浮卡片」外观:圆角表面 + 1px 描边 + 柔和投影。
///
/// 输入框原先是一块与聊天区同底的扁平色带,和上方的对话内容之间没有任何
/// 层次,读起来像「贴在页面上的一个条」。这里把它改成一张浮起来的卡片:
/// 表面比聊天区底色略亮、四周留出间距、边缘带一圈极淡的描边、底下压一层
/// 柔和投影,卡片因此从背景里立了起来。
struct ComposerSurfaceModifier: ViewModifier {
    @LumiTheme private var theme
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .appSurface(
                style: .panel,
                cornerRadius: ComposerLayout.cornerRadius,
                borderColor: theme.divider
            )
            .padding(.horizontal, ComposerLayout.outerHorizontalInset)
            .padding(.top, ComposerLayout.outerTopInset)
            .padding(.bottom, ComposerLayout.outerBottomInset)
            .shadow(
                color: shadowColor,
                radius: ComposerLayout.shadowRadius,
                y: ComposerLayout.shadowOffsetY
            )
    }

    /// 投影颜色。
    ///
    /// 暗色主题下同样的黑色几乎压不出层次,故暗色用更高的不透明度。
    private var shadowColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.55) : Color.black.opacity(0.13)
    }
}

extension View {
    /// 把视图变成输入框的悬浮卡片。
    func composerSurface() -> some View {
        modifier(ComposerSurfaceModifier())
    }
}
