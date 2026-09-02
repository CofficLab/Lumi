import KitWebServer
import LumiUI
import SwiftUI

/// Web Server 设置页：展示服务当前的只读运行信息。
struct WebServerSettingsView: View {
    let server: LumiWebServer

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    AppSettingSection(title: "状态") {
                        AppSettingsReadOnlyRow(
                            "运行状态",
                            description: server.isRunning ? "服务正在接受本机 HTTP 请求。" : "服务当前未运行。",
                            badge: server.isRunning ? "运行中" : "已停止"
                        )
                        AppSettingsReadOnlyRow(
                            "已注册路由",
                            description: "由已启用插件提供的 HTTP 路由数量。",
                            badge: "\(server.registeredRouteCount)"
                        )
                    }

                    AppSettingSection(title: "连接信息") {
                        AppSettingsReadOnlyRow(
                            "监听地址",
                            description: server.listenHost == "127.0.0.1" ? "仅本机可访问。" : "可能可被局域网设备访问。",
                            badge: server.listenHost
                        )
                        AppSettingsReadOnlyRow(
                            "端口",
                            description: "服务配置端口；启动成功后使用该端口访问。",
                            badge: "\(server.boundPort ?? server.port)"
                        )
                        AppSettingsReadOnlyRow(
                            "认证",
                            description: "请求是否需要 Bearer Token。",
                            badge: server.hasAuthentication ? "已启用" : "未配置"
                        )
                    }

                    AppSettingSection(title: "发现接口") {
                        AppSettingsReadOnlyRow(
                            "GET /api/plugins",
                            description: "列出当前已注册的 Web Server 路由。",
                            badge: "HTTP"
                        )
                    }
                }
                .frame(maxWidth: 620, alignment: .leading)
                .padding(22)
            }
        }
    }
}

#Preview {
    WebServerSettingsView(server: LumiWebServer())
        .frame(width: 560, height: 620)
}
