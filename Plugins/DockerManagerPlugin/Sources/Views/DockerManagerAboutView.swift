import LumiUI
import SwiftUI

/// Docker 管理插件关于视图 —— 以「镜像管理 + 命令清单」为主轴的落地页。
struct DockerManagerAboutView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            hero
            capabilitiesSection
            commandsSection
        }
    }

    // MARK: - Hero

    private var hero: some View {
        LandingHero(
            icon: "cylinder.split.1x2",
            accent: theme.info,
            tagline: L("图形化管理本地 Docker 镜像:浏览、分层查看、打标签、清理闲置镜像,释放磁盘空间。"),
            chips: [L("镜像管理"), L("分层查看"), L("标签"), L("清理")],
            metrics: [
                .init(value: "4", label: L("核心能力")),
                .init(value: "镜像", label: L("管理对象")),
                .init(value: "1键", label: L("清理闲置"))
            ]
        )
        .landingAppear()
    }

    // MARK: - 镜像能力

    private var capabilitiesSection: some View {
        LandingSection(title: L("镜像能力"), icon: "square.stack.3d.up") {
            LandingFeatureGrid(items: [
                .init(icon: "shippingbox", tint: theme.info,
                      title: L("镜像管理"),
                      description: L("浏览、查看详情并管理本地 Docker 镜像。")),
                .init(icon: "rectangle.split.3x1", tint: theme.primary,
                      title: L("分层查看"),
                      description: L("查看镜像各分层及其占用大小。")),
                .init(icon: "tag", tint: theme.warning,
                      title: L("标签管理"),
                      description: L("管理镜像的标签与版本。")),
                .init(icon: "trash", tint: theme.error,
                      title: L("镜像清理"),
                      description: L("移除未使用的镜像,释放磁盘空间。"))
            ])
        }
        .landingAppear(delay: 0.05)
    }

    // MARK: - 覆盖命令

    private var commandsSection: some View {
        LandingSection(title: L("图形化覆盖的常用命令"), icon: "terminal") {
            LandingInventory(tint: theme.info, items: [
                .init(icon: "square.grid.2x2", title: "docker images", description: L("镜像清单"), mono: true),
                .init(icon: "rectangle.stack", title: "docker ps", description: L("运行中容器"), mono: true),
                .init(icon: "play", title: "docker run", description: L("启动容器"), mono: true),
                .init(icon: "trash", title: "docker rmi", description: L("删除镜像"), mono: true),
                .init(icon: "sparkles", title: "docker image prune", description: L("清理闲置镜像"), mono: true)
            ])
        }
        .landingAppear(delay: 0.1)
    }

    // MARK: - Localization

    private func L(_ key: String) -> String {
        LumiPluginLocalization.string(key, bundle: .module)
    }
}

#Preview {
    ScrollView {
        DockerManagerAboutView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
