import KitWebServer
import LumiUI
import SwiftUI

/// Web Server 设置页：展示服务当前的只读运行信息。
struct WebServerSettingsView: View {
    let server: LumiWebServer

    @LumiTheme private var theme

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            AppSettingsContentScaffold(maxContentWidth: nil) {
                VStack(alignment: .leading, spacing: 24) {
                    statusSection
                    connectionSection
                    discoverySection
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .environment(\.appSettingsCardStyleOverride, .subtle)
        }
    }

    // MARK: - 状态

    private var statusSection: some View {
        AppCard {
            AppSettingsSection(
                title: "状态"
            ) {
                AppSettingsRow {
                    HStack(spacing: 12) {
                        Image(systemName: "power")
                            .font(.appCallout)
                            .foregroundColor(theme.primary)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("运行状态")
                                .font(.appBody)
                                .foregroundColor(theme.textPrimary)
                            Text(server.isRunning ? "服务正在接受本机 HTTP 请求。" : "服务当前未运行。")
                                .font(.appCaption)
                                .foregroundColor(theme.textSecondary)
                        }

                        Spacer()

                        Text(server.isRunning ? "运行中" : "已停止")
                            .font(.appCaption)
                            .foregroundStyle(server.isRunning ? .green : .secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(server.isRunning ? Color.green.opacity(0.15) : Color.secondary.opacity(0.15))
                            )
                    }
                }

                AppSettingsRow {
                    HStack(spacing: 12) {
                        Image(systemName: "link")
                            .font(.appCallout)
                            .foregroundColor(theme.primary)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("已注册路由")
                                .font(.appBody)
                                .foregroundColor(theme.textPrimary)
                            Text("由已启用插件提供的 HTTP 路由数量。")
                                .font(.appCaption)
                                .foregroundColor(theme.textSecondary)
                        }

                        Spacer()

                        Text("\(server.registeredRouteCount)")
                            .font(.appCaption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.secondary.opacity(0.15))
                            )
                    }
                }
            }
        }
    }

    // MARK: - 连接信息

    private var connectionSection: some View {
        AppCard {
            AppSettingsSection(
                title: "连接信息"
            ) {
                AppSettingsRow {
                    HStack(spacing: 12) {
                        Image(systemName: "network")
                            .font(.appCallout)
                            .foregroundColor(theme.primary)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("监听地址")
                                .font(.appBody)
                                .foregroundColor(theme.textPrimary)
                            Text(server.listenHost == "127.0.0.1" ? "仅本机可访问。" : "可能可被局域网设备访问。")
                                .font(.appCaption)
                                .foregroundColor(theme.textSecondary)
                        }

                        Spacer()

                        Text(server.listenHost)
                            .font(.appCaption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.secondary.opacity(0.15))
                            )
                    }
                }

                AppSettingsRow {
                    HStack(spacing: 12) {
                        Image(systemName: "number")
                            .font(.appCallout)
                            .foregroundColor(theme.primary)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("端口")
                                .font(.appBody)
                                .foregroundColor(theme.textPrimary)
                            Text("服务配置端口；启动成功后使用该端口访问。")
                                .font(.appCaption)
                                .foregroundColor(theme.textSecondary)
                        }

                        Spacer()

                        Text("\(server.boundPort ?? server.port)")
                            .font(.appCaption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.secondary.opacity(0.15))
                            )
                    }
                }

                AppSettingsRow {
                    HStack(spacing: 12) {
                        Image(systemName: "lock.shield")
                            .font(.appCallout)
                            .foregroundColor(theme.primary)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("认证")
                                .font(.appBody)
                                .foregroundColor(theme.textPrimary)
                            Text("请求是否需要 Bearer Token。")
                                .font(.appCaption)
                                .foregroundColor(theme.textSecondary)
                        }

                        Spacer()

                        Text(server.hasAuthentication ? "已启用" : "未配置")
                            .font(.appCaption)
                            .foregroundStyle(server.hasAuthentication ? .green : .secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(server.hasAuthentication ? Color.green.opacity(0.15) : Color.secondary.opacity(0.15))
                            )
                    }
                }
            }
        }
    }

    // MARK: - 发现接口

    private var discoverySection: some View {
        AppCard {
            AppSettingsSection(
                title: "发现接口"
            ) {
                AppSettingsRow {
                    HStack(spacing: 12) {
                        Image(systemName: "doc.plaintext")
                            .font(.appCallout)
                            .foregroundColor(theme.primary)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("GET /api/plugins")
                                .font(.appBody)
                                .foregroundColor(theme.textPrimary)
                            Text("列出当前已注册的 Web Server 路由。")
                                .font(.appCaption)
                                .foregroundColor(theme.textSecondary)
                        }

                        Spacer()

                        Text("HTTP")
                            .font(.appCaption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.secondary.opacity(0.15))
                            )
                    }
                }
            }
        }
    }
}

#Preview {
    WebServerSettingsView(server: LumiWebServer())
        .frame(width: 560, height: 620)
}
