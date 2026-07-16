import LumiUI
import SwiftUI

/// GitHub 插件关于视图 - 展示插件的功能介绍和说明
public struct GitHubPluginAboutView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题和描述
            Text(LumiPluginLocalization.string("GitHub 集成", bundle: .module))
                .font(.title2.weight(.semibold))

            Text(LumiPluginLocalization.string(
                "GitHub CLI 检测、生态洞察知识库以及完整的 GitHub API 工具集。支持代码仓库查询、Issue 管理、趋势项目浏览等功能。",
                bundle: .module
            ))
            .font(.appCaption)
            .foregroundStyle(.secondary)

            Divider()

            // 主要功能特性
            VStack(alignment: .leading, spacing: 12) {
                Text(LumiPluginLocalization.string("核心功能", bundle: .module))
                    .font(.appBodyEmphasized)

                FeatureRow(
                    icon: "terminal",
                    title: LumiPluginLocalization.string("CLI 检测", bundle: .module),
                    description: LumiPluginLocalization.string("自动检测系统中是否安装了 GitHub CLI (gh)", bundle: .module)
                )

                FeatureRow(
                    icon: "book.closed",
                    title: LumiPluginLocalization.string("生态洞察", bundle: .module),
                    description: LumiPluginLocalization.string("基于本地知识库的 GitHub 生态系统问答", bundle: .module)
                )

                FeatureRow(
                    icon: "network",
                    title: LumiPluginLocalization.string("API 工具", bundle: .module),
                    description: LumiPluginLocalization.string("通过 GitHub API 进行仓库查询、Issue 管理等操作", bundle: .module)
                )

                FeatureRow(
                    icon: "chart.bar.fill",
                    title: LumiPluginLocalization.string("趋势项目", bundle: .module),
                    description: LumiPluginLocalization.string("浏览 GitHub 上的热门项目和趋势", bundle: .module)
                )
            }

            Divider()

            // 使用说明
            VStack(alignment: .leading, spacing: 8) {
                Text(LumiPluginLocalization.string("使用提示", bundle: .module))
                    .font(.appBodyEmphasized)

                HStack(spacing: 6) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(theme.info)
                    Text(LumiPluginLocalization.string(
                        "配置 Personal Access Token 可提高 API 调用限额（从 60 次/小时提升到 5,000 次/小时）",
                        bundle: .module
                    ))
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
                }

                HStack(spacing: 6) {
                    Image(systemName: "lock.shield")
                        .foregroundColor(theme.success)
                    Text(LumiPluginLocalization.string("Token 仅存储在本地，不会上传到任何服务器", bundle: .module))
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

// MARK: - Feature Row Helper

private struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .frame(width: 24, height: 24)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.appBody)
                Text(description)
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}

#Preview {
    GitHubPluginAboutView()
        .frame(width: 500, height: 700)
}
