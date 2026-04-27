import SwiftUI

// MARK: - VS Code 亮色主题
///
/// 严格遵循 Visual Studio Code Light+ (Light Modern) 默认配色方案。
/// 特点：清爽明快的经典 IDE 亮色体验
///
struct VscodeLightTheme: ThemeProtocol {
    // MARK: - 主题信息
    let identifier = "vscode-light"
    let displayName = "VS Code 亮色"
    let compactName = "VSCode亮"
    let description = "Visual Studio Code Light+ 经典亮色 IDE 配色"
    let iconName = "terminal"

    var iconColor: SwiftUI.Color {
        SwiftUI.Color(hex: "007ACC")
    }

    // MARK: - 颜色配置

    func accentColors() -> (primary: SwiftUI.Color, secondary: SwiftUI.Color, tertiary: SwiftUI.Color) {
        (
            primary: SwiftUI.Color(hex: "007ACC"),       // VS Code 标志性蓝色
            secondary: SwiftUI.Color(hex: "A31515"),      // VS Code 深红（字符串/强调色亮色模式）
            tertiary: SwiftUI.Color(hex: "795E26")        // VS Code 深棕（函数/方法名）
        )
    }

    func atmosphereColors() -> (deep: SwiftUI.Color, medium: SwiftUI.Color, light: SwiftUI.Color) {
        (
            deep: SwiftUI.Color(hex: "F3F3F3"),          // VS Code 亮色背景 (非纯白)
            medium: SwiftUI.Color(hex: "FFFFFF"),         // VS Code 编辑器/卡片白色
            light: SwiftUI.Color(hex: "E8E8E8")           // VS Code 工具栏/边框灰色
        )
    }

    func glowColors() -> (subtle: SwiftUI.Color, medium: SwiftUI.Color, intense: SwiftUI.Color) {
        (
            subtle: SwiftUI.Color(hex: "007ACC").opacity(0.12),
            medium: SwiftUI.Color(hex: "007ACC").opacity(0.2),
            intense: SwiftUI.Color(hex: "007ACC").opacity(0.3)
        )
    }

    func makeGlobalBackground(proxy: GeometryProxy) -> AnyView {
        AnyView(
            ZStack {
                atmosphereColors().deep
                    .ignoresSafeArea()

                // VS Code 蓝主光晕 (中心偏上)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                accentColors().primary.opacity(0.08),
                                SwiftUI.Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 300
                        )
                    )
                    .frame(width: 600, height: 600)
                    .blur(radius: 120)
                    .position(x: proxy.size.width * 0.5, y: 100)

                // 深红光晕 (右下)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                accentColors().secondary.opacity(0.04),
                                SwiftUI.Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 250
                        )
                    )
                    .frame(width: 500, height: 500)
                    .blur(radius: 100)
                    .position(x: proxy.size.width - 100, y: proxy.size.height - 100)

                // IDE 风格装饰
                ZStack {
                    Rectangle()
                        .fill(accentColors().primary.opacity(0.03))
                        .frame(width: 1, height: proxy.size.height)
                        .offset(x: -300)

                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: 350))
                        .foregroundStyle(accentColors().primary.opacity(0.02))
                        .rotationEffect(.degrees(-10))
                        .position(x: proxy.size.width * 0.75, y: proxy.size.height * 0.6)
                        .blur(radius: 3)

                    Image(systemName: "terminal")
                        .font(.system(size: 180))
                        .foregroundStyle(accentColors().secondary.opacity(0.025))
                        .rotationEffect(.degrees(8))
                        .position(x: proxy.size.width * 0.25, y: proxy.size.height * 0.25)
                        .blur(radius: 2)
                }
            }
        )
    }
}
