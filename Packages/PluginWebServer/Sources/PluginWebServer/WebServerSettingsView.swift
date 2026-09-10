import KitWebServer
import LumiUI
import SwiftUI

/// Web Server 设置页：展示服务当前的只读运行信息。
struct WebServerSettingsView: View {
    let server: LumiWebServer

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
        }
    }

    // MARK: - 状态

    private var statusSection: some View {
        AppSettingSection(
            title: "状态",
            titleAlignment: .leading
        ) {
            VStack(spacing: 0) {
                AppSettingRow(
                    title: "运行状态",
                    description: server.isRunning ? "服务正在接受本机 HTTP 请求。" : "服务当前未运行。",
                    icon: "power"
                ) {
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

                Divider()
                    .padding(.vertical, 8)

                AppSettingRow(
                    title: "已注册路由",
                    description: "由已启用插件提供的 HTTP 路由数量。",
                    icon: "link"
                ) {
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

    // MARK: - 连接信息

    private var connectionSection: some View {
        AppSettingSection(
            title: "连接信息",
            titleAlignment: .leading
        ) {
            VStack(spacing: 0) {
                AppSettingRow(
                    title: "监听地址",
                    description: server.listenHost == "127.0.0.1" ? "仅本机可访问。" : "可能可被局域网设备访问。",
                    icon: "network"
                ) {
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

                Divider()
                    .padding(.vertical, 8)

                AppSettingRow(
                    title: "端口",
                    description: "服务配置端口；启动成功后使用该端口访问。",
                    icon: "number"
                ) {
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

                Divider()
                    .padding(.vertical, 8)

                AppSettingRow(
                    title: "认证",
                    description: "请求是否需要 Bearer Token。",
                    icon: "lock.shield"
                ) {
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

    // MARK: - 发现接口

    private var discoverySection: some View {
        AppSettingSection(
            title: "发现接口",
            titleAlignment: .leading
        ) {
            AppSettingRow(
                title: "GET /api/plugins",
                description: "列出当前已注册的 Web Server 路由。",
                icon: "doc.plaintext"
            ) {
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

#Preview {
    WebServerSettingsView(server: LumiWebServer())
        .frame(width: 560, height: 620)
}
