import SwiftUI

/// 欢迎视图：显示应用欢迎界面和使用指南
struct WelcomeView: View {
    @EnvironmentObject var app: AppProvider

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer()
                    .frame(height: 40)

                // 主要欢迎内容
                welcomeSection

                // 功能特性
                featuresSection

                // 快速开始
                quickStartSection

                Spacer()
            }
            .padding(40)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - 欢迎区域

    private var welcomeSection: some View {
        VStack(spacing: 16) {
            Image(systemName: WelcomePlugin.iconName)
                .resizable()
                .frame(width: 100, height: 100)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("欢迎使用 SwiftUI Template")
                .font(.title)
                .fontWeight(.bold)

            Text("这是一个现代化的macOS应用模板，基于SwiftUI构建")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    // MARK: - 功能特性区域

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("核心特性")
                .font(.title2)
                .fontWeight(.semibold)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                FeatureCard(
                    icon: "puzzlepiece.extension",
                    title: "插件系统",
                    description: "灵活的插件架构，轻松扩展功能"
                )
                FeatureCard(
                    icon: "gearshape",
                    title: "设置管理",
                    description: "完善的应用设置和配置"
                )
                FeatureCard(
                    icon: "swift",
                    title: "SwiftUI",
                    description: "使用最新的SwiftUI技术构建"
                )
                FeatureCard(
                    icon: "rectangle.stack",
                    title: "模块化设计",
                    description: "清晰的代码组织结构"
                )
            }
        }
    }

    // MARK: - 快速开始区域

    private var quickStartSection: some View {
        VStack(spacing: 16) {
            Text("快速开始")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(spacing: 12) {
                ActionButton(
                    icon: "gear",
                    title: "查看设置",
                    description: "配置应用偏好设置"
                ) {
                    NotificationCenter.postOpenSettings()
                }

                ActionButton(
                    icon: "puzzlepiece.extension",
                    title: "插件管理",
                    description: "查看和管理已安装的插件"
                ) {
                    NotificationCenter.postOpenSettings()
                }
            }
        }
    }
}

/// 功能卡片组件
private struct FeatureCard: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 40, height: 40)

            Text(title)
                .font(.headline)
                .fontWeight(.semibold)

            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

/// 操作按钮组件
private struct ActionButton: View {
    let icon: String
    let title: String
    let description: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.blue)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview("Welcome View") {
    WelcomeView()
        .frame(width: 700, height: 800)
}

#Preview("App - Small Screen") {
    ContentLayout()
        .hideSidebar()
        .hideTabPicker()
        .inRootView()
        .frame(width: 800)
        .frame(height: 600)
}

#Preview("App - Big Screen") {
    ContentLayout()
        .hideSidebar()
        .inRootView()
        .frame(width: 1200)
        .frame(height: 1200)
}
