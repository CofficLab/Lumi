import SwiftUI

// MARK: - VS Code 深色主题
///
/// 严格遵循 Visual Studio Code Dark+ (Dark Modern) 默认配色方案。
/// 特点：专业开发者的经典深色 IDE 体验
///
struct VscodeDarkTheme: SuperTheme {
    // MARK: - 主题信息
    let identifier = "vscode-dark"
    let displayName = "VS Code 深色"
    let compactName = "VSCode暗"
    let description = "Visual Studio Code Dark+ 经典深色 IDE 配色"
    let iconName = "terminal.fill"

    var iconColor: SwiftUI.Color {
        SwiftUI.Color.adaptive(light: "007ACC", dark: "007ACC")
    }

    // MARK: - 颜色配置

    func accentColors() -> (primary: SwiftUI.Color, secondary: SwiftUI.Color, tertiary: SwiftUI.Color) {
        (
            primary: SwiftUI.Color(hex: "007ACC"),       // VS Code 标志性蓝色
            secondary: SwiftUI.Color(hex: "C586C0"),      // VS Code 紫罗兰（关键字/装饰色）
            tertiary: SwiftUI.Color(hex: "D7BA7D")        // VS Code 暖黄（字符串/强调色）
        )
    }

    func atmosphereColors() -> (deep: SwiftUI.Color, medium: SwiftUI.Color, light: SwiftUI.Color) {
        (
            deep: SwiftUI.Color(hex: "1E1E1E"),          // VS Code 编辑器背景
            medium: SwiftUI.Color(hex: "252526"),         // VS Code 侧边栏/活动栏背景
            light: SwiftUI.Color(hex: "2D2D2D")           // VS Code 标题栏/输入框背景
        )
    }

    func glowColors() -> (subtle: SwiftUI.Color, medium: SwiftUI.Color, intense: SwiftUI.Color) {
        (
            subtle: SwiftUI.Color(hex: "007ACC").opacity(0.25),
            medium: SwiftUI.Color(hex: "007ACC").opacity(0.4),
            intense: SwiftUI.Color(hex: "C586C0").opacity(0.35)
        )
    }

    func makeGlobalBackground(proxy: GeometryProxy) -> AnyView {
        AnyView(
            ZStack {
                atmosphereColors().deep
                    .ignoresSafeArea()

                // VS Code 蓝主光晕 (左上)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                accentColors().primary.opacity(0.15),
                                SwiftUI.Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 350
                        )
                    )
                    .frame(width: 700, height: 700)
                    .blur(radius: 130)
                    .position(x: 150, y: 150)

                // 紫罗兰光晕 (右下)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                accentColors().secondary.opacity(0.08),
                                SwiftUI.Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 300
                        )
                    )
                    .frame(width: 600, height: 600)
                    .blur(radius: 100)
                    .position(x: proxy.size.width - 150, y: proxy.size.height - 150)

                // IDE 风格装饰
                ZStack {
                    // 类似行号的装饰线
                    Rectangle()
                        .fill(accentColors().primary.opacity(0.04))
                        .frame(width: 1, height: proxy.size.height)
                        .offset(x: -300)

                    // VS Code 图标元素
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: 350))
                        .foregroundStyle(accentColors().primary.opacity(0.03))
                        .rotationEffect(.degrees(-10))
                        .position(x: proxy.size.width * 0.7, y: proxy.size.height * 0.7)
                        .blur(radius: 3)

                    Image(systemName: "terminal")
                        .font(.system(size: 180))
                        .foregroundStyle(accentColors().secondary.opacity(0.04))
                        .rotationEffect(.degrees(8))
                        .position(x: proxy.size.width * 0.3, y: proxy.size.height * 0.25)
                        .blur(radius: 2)
                }
            }
        )
    }
}
